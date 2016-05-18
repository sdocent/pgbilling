--
-- NETWORK
--

SET SCHEMA 'network';

-- network.addr_houses

CREATE OR REPLACE VIEW addr_houses AS
    SELECT *, system.services_get_addr(house_id, 0) AS postaddr FROM system.addr_houses;

-- Functions

CREATE OR REPLACE FUNCTION rad_check(vc_username varchar, vc_remoteid varchar, vc_circuitid varchar)
RETURNS TABLE(id integer, username varchar, attribute varchar, value varchar, op varchar) AS $$
DECLARE
	m_password varchar;
BEGIN
	SELECT service_pass INTO m_password FROM system.services WHERE service_name = vc_username;
	IF NOT FOUND THEN
		RETURN;
	END IF;

    id := 1;
    username := vc_username;
    attribute := 'Cleartext-Password';
    value := m_password;
    op := ':=';
    RETURN NEXT;
END
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION rad_reply(vc_username varchar, vc_remoteid varchar, vc_circuitid varchar)
RETURNS TABLE(id integer, username varchar, attribute varchar, value varchar, op varchar) AS $$
DECLARE
	m_service system.services%rowtype;
	m_attr system.radius_attrs%rowtype;
	m_ip inet;
BEGIN
	SELECT * INTO m_service FROM system.services WHERE service_name = vc_username;
	IF NOT FOUND THEN
		RETURN;
	END IF;

	FOR m_attr IN SELECT * FROM system.radius_attrs WHERE service_state = m_service.service_state
	LOOP
		value := m_attr.attr_value;
		SELECT replace(value, '{kbps}', m_service.inet_speed::varchar) INTO value;
		SELECT replace(value, '{Bps}', (m_service.inet_speed * 128)::varchar) INTO value;

		id := m_attr.attr_id;
		username := vc_username;
		attribute := m_attr.attr_name;
		op := ':=';
		RETURN NEXT;
	END LOOP;

	FOR m_ip IN SELECT ip_address FROM system.services_addr WHERE service_id = m_service.service_id
		AND family(ip_address) = 4
	LOOP
		id := 0;
		op := ':=';
		username := vc_username;

		attribute := 'Framed-IP-Address';
		value := m_ip;
		RETURN NEXT;
		
		attribute := 'Service-Type';
		value := 'Framed-User';
		RETURN NEXT;
	END LOOP;
END
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- GRANT to network

GRANT USAGE ON SCHEMA network TO network;
GRANT SELECT,INSERT,UPDATE,DELETE ON ALL TABLES IN SCHEMA network TO network;
