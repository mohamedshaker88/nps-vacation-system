-- Fix SQL syntax error in get_exchange_request_status function
CREATE OR REPLACE FUNCTION get_exchange_request_status(p_request_id INTEGER)
RETURNS JSONB AS $$
DECLARE
    request_row requests%ROWTYPE;
    partner_name TEXT;
    result JSONB;
BEGIN
    -- Get the request first
    SELECT * INTO request_row FROM requests WHERE id = p_request_id;
    
    -- Get partner name separately if there is a partner
    IF request_row.exchange_partner_id IS NOT NULL THEN
        SELECT name INTO partner_name 
        FROM employees 
        WHERE id = request_row.exchange_partner_id;
    END IF;
    
    result := jsonb_build_object(
        'request_id', request_row.id,
        'status', request_row.status,
        'exchange_partner_id', request_row.exchange_partner_id,
        'exchange_partner_name', partner_name,
        'exchange_partner_approved', request_row.exchange_partner_approved,
        'exchange_partner_approved_at', request_row.exchange_partner_approved_at,
        'can_admin_approve', CASE 
            WHEN request_row.exchange_partner_id IS NULL THEN true
            WHEN request_row.exchange_partner_approved = true THEN true
            ELSE false
        END
    );
    
    RETURN result;
END;
$$ LANGUAGE plpgsql; 