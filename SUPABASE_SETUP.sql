-- NEXORA production setup
-- Run these in Supabase SQL Editor, one query at a time.

-- 1) Remove the earlier direct-anonymous INSERT policy.
DROP POLICY IF EXISTS "Allow public RSVP submissions" ON public.registration;
REVOKE INSERT ON public.registration FROM anon;

-- Public RSVP creation RPC (keeps attendee data private from anonymous users)
CREATE OR REPLACE FUNCTION public.create_registration(
  p_full_name text,
  p_email text,
  p_phone text,
  p_age integer,
  p_business_name text,
  p_business_type text
)
RETURNS TABLE(id uuid, ticket_code text, created_at timestamptz)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF length(trim(p_full_name)) < 2 THEN RAISE EXCEPTION 'Please enter a valid full name'; END IF;
  IF p_age < 10 OR p_age > 100 THEN RAISE EXCEPTION 'Invalid age'; END IF;
  IF p_business_type NOT IN ('Startup','Family Business') THEN RAISE EXCEPTION 'Invalid business type'; END IF;

  RETURN QUERY
  INSERT INTO public.registration(full_name,email,phone,age,business_name,business_type,ticket_code,checked_in)
  VALUES (trim(p_full_name),trim(p_email),trim(p_phone),p_age,NULLIF(trim(p_business_name),''),p_business_type,'',false)
  RETURNING registration.id, registration.ticket_code, registration.created_at;
END;
$$;

REVOKE ALL ON FUNCTION public.create_registration(text,text,text,integer,text,text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.create_registration(text,text,text,integer,text,text) TO anon;

-- 2) Admin check-in RPC. Admins must be authenticated.
CREATE OR REPLACE FUNCTION public.checkin_ticket(p_ticket_code text)
RETURNS TABLE(status text, full_name text, ticket_code text, checked_in_at timestamptz)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE r public.registration%ROWTYPE;
BEGIN
  IF auth.uid() IS NULL THEN RAISE EXCEPTION 'Authentication required'; END IF;
  SELECT * INTO r FROM public.registration WHERE upper(ticket_code)=upper(trim(p_ticket_code)) FOR UPDATE;
  IF NOT FOUND THEN RETURN QUERY SELECT 'not_found'::text,NULL::text,NULL::text,NULL::timestamptz; RETURN; END IF;
  IF r.checked_in THEN RETURN QUERY SELECT 'already_checked_in'::text,r.full_name,r.ticket_code,r.checked_in_at; RETURN; END IF;
  UPDATE public.registration SET checked_in=true, checked_in_at=now() WHERE id=r.id RETURNING * INTO r;
  RETURN QUERY SELECT 'checked_in'::text,r.full_name,r.ticket_code,r.checked_in_at;
END;
$$;

REVOKE ALL ON FUNCTION public.checkin_ticket(text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.checkin_ticket(text) TO authenticated;

-- 3) Authenticated admin dashboard can read registrations.
CREATE POLICY "Admins can read registrations"
ON public.registration FOR SELECT TO authenticated USING (true);

-- Optional: if you already created a broad anon INSERT policy, it can remain;
-- the public RPC above is the intended production path.
