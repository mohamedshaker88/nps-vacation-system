-- True Bidirectional Exchange System
-- This script implements proper two-way exchange where both employees swap their schedules

-- 1. Create function to swap work schedules between two employees for specific dates
CREATE OR REPLACE FUNCTION swap_work_schedules_bidirectional(
    p_employee1_id BIGINT,
    p_employee2_id BIGINT, 
    p_employee1_date DATE,  -- Date employee1 wants to have off
    p_employee2_date DATE   -- Date employee2 wants to have off
) RETURNS JSONB AS $$
DECLARE
    emp1_week_start DATE;
    emp2_week_start DATE;
    emp1_day_of_week INTEGER;
    emp2_day_of_week INTEGER;
    emp1_day_column VARCHAR(20);
    emp2_day_column VARCHAR(20);
    emp1_schedule_id BIGINT;
    emp2_schedule_id BIGINT;
    emp1_original_status VARCHAR(20);
    emp2_original_status VARCHAR(20);
    result JSONB;
BEGIN
    -- Calculate week start dates (Monday = 1)
    emp1_day_of_week := EXTRACT(DOW FROM p_employee1_date);
    emp2_day_of_week := EXTRACT(DOW FROM p_employee2_date);
    
    -- Convert Sunday (0) to 7 for proper calculation
    IF emp1_day_of_week = 0 THEN emp1_day_of_week := 7; END IF;
    IF emp2_day_of_week = 0 THEN emp2_day_of_week := 7; END IF;
    
    emp1_week_start := p_employee1_date - (emp1_day_of_week - 1);
    emp2_week_start := p_employee2_date - (emp2_day_of_week - 1);
    
    -- Get day column names
    emp1_day_column := CASE emp1_day_of_week
        WHEN 1 THEN 'monday_status'
        WHEN 2 THEN 'tuesday_status'
        WHEN 3 THEN 'wednesday_status'
        WHEN 4 THEN 'thursday_status'
        WHEN 5 THEN 'friday_status'
        WHEN 6 THEN 'saturday_status'
        WHEN 7 THEN 'sunday_status'
    END;
    
    emp2_day_column := CASE emp2_day_of_week
        WHEN 1 THEN 'monday_status'
        WHEN 2 THEN 'tuesday_status'
        WHEN 3 THEN 'wednesday_status'
        WHEN 4 THEN 'thursday_status'
        WHEN 5 THEN 'friday_status'
        WHEN 6 THEN 'saturday_status'
        WHEN 7 THEN 'sunday_status'
    END;
    
    -- Get or create work schedules
    emp1_schedule_id := get_or_create_work_schedule(p_employee1_id, emp1_week_start);
    emp2_schedule_id := get_or_create_work_schedule(p_employee2_id, emp2_week_start);
    
    -- Get current statuses
    EXECUTE format('SELECT %I FROM work_schedules WHERE id = $1', emp1_day_column)
    INTO emp1_original_status
    USING emp1_schedule_id;
    
    EXECUTE format('SELECT %I FROM work_schedules WHERE id = $1', emp2_day_column)
    INTO emp2_original_status
    USING emp2_schedule_id;
    
    -- Perform the bidirectional swap
    -- Employee 1: Gets employee 2's original status on employee 1's date
    -- Employee 2: Gets employee 1's original status on employee 2's date
    EXECUTE format('UPDATE work_schedules SET %I = $1 WHERE id = $2', emp1_day_column)
    USING emp2_original_status, emp1_schedule_id;
    
    EXECUTE format('UPDATE work_schedules SET %I = $1 WHERE id = $2', emp2_day_column)
    USING emp1_original_status, emp2_schedule_id;
    
    -- Build result
    result := jsonb_build_object(
        'success', true,
        'employee1_id', p_employee1_id,
        'employee2_id', p_employee2_id,
        'employee1_date', p_employee1_date,
        'employee2_date', p_employee2_date,
        'employee1_status_change', emp1_original_status || ' → ' || emp2_original_status,
        'employee2_status_change', emp2_original_status || ' → ' || emp1_original_status,
        'message', 'Schedules swapped successfully'
    );
    
    RETURN result;
END;
$$ LANGUAGE plpgsql;

-- 2. Update the exchange request approval function to handle bidirectional exchange
CREATE OR REPLACE FUNCTION approve_exchange_request_bidirectional(
    p_request_id INTEGER,
    p_employee_id INTEGER,
    p_approved BOOLEAN,
    p_notes TEXT DEFAULT NULL
) RETURNS JSONB AS $$
DECLARE
    request_row requests%ROWTYPE;
    requester_employee employees%ROWTYPE;
    partner_employee employees%ROWTYPE;
    swap_result JSONB;
    result JSONB;
BEGIN
    -- Get the request
    SELECT * INTO request_row FROM requests WHERE id = p_request_id;
    
    -- Check if request exists
    IF request_row.id IS NULL THEN
        RETURN jsonb_build_object('success', false, 'message', 'Request not found');
    END IF;
    
    -- Check if this employee is the exchange partner
    IF request_row.exchange_partner_id != p_employee_id THEN
        RETURN jsonb_build_object('success', false, 'message', 'You are not the exchange partner for this request');
    END IF;
    
    -- Check if already responded
    IF request_row.exchange_partner_approved IS NOT NULL THEN
        RETURN jsonb_build_object('success', false, 'message', 'You have already responded to this request');
    END IF;
    
    -- Update the request with partner approval
    UPDATE requests 
    SET 
        exchange_partner_approved = p_approved,
        exchange_partner_approved_at = NOW(),
        exchange_partner_notes = p_notes,
        status = CASE 
            WHEN p_approved = true THEN 'Partner Approved'
            ELSE 'Rejected'
        END
    WHERE id = p_request_id;
    
    -- Get employee details for notifications
    SELECT * INTO requester_employee FROM employees WHERE id = request_row.employee_id;
    SELECT * INTO partner_employee FROM employees WHERE id = p_employee_id;
    
    -- Create notification for requester
    INSERT INTO notifications (employee_id, type, title, message, is_read)
    VALUES (
        request_row.employee_id,
        CASE WHEN p_approved THEN 'exchange_partner_approved' ELSE 'exchange_partner_rejected' END,
        CASE WHEN p_approved THEN 'Exchange Partner Approved' ELSE 'Exchange Partner Rejected' END,
        CASE 
            WHEN p_approved THEN 
                format('Your exchange request has been approved by %s. Admin approval is now required. You will have off on %s and work on %s.', 
                       partner_employee.name, 
                       request_row.exchange_from_date,
                       request_row.exchange_to_date)
            ELSE 
                format('Your exchange request has been rejected by %s. Reason: %s', 
                       partner_employee.name, 
                       COALESCE(p_notes, 'No reason provided'))
        END,
        false
    );
    
    RETURN jsonb_build_object(
        'success', true, 
        'message', CASE WHEN p_approved THEN 'Request approved successfully' ELSE 'Request rejected' END,
        'new_status', CASE WHEN p_approved THEN 'Partner Approved' ELSE 'Rejected' END,
        'requester', requester_employee.name,
        'partner', partner_employee.name
    );
END;
$$ LANGUAGE plpgsql;

-- 3. Update the admin approval trigger to use bidirectional swap
CREATE OR REPLACE FUNCTION update_request_status_and_schedules_bidirectional()
RETURNS TRIGGER AS $$
DECLARE
    partner_employee employees%ROWTYPE;
    requester_employee employees%ROWTYPE;
    swap_result JSONB;
BEGIN
    -- Only process when status changes to 'Approved'
    IF NEW.status = 'Approved' AND OLD.status != 'Approved' THEN
        -- If this is an exchange request, perform bidirectional swap
        IF NEW.exchange_partner_id IS NOT NULL AND NEW.exchange_from_date IS NOT NULL AND NEW.exchange_to_date IS NOT NULL THEN
            -- Get employee details
            SELECT * INTO requester_employee FROM employees WHERE id = NEW.employee_id;
            SELECT * INTO partner_employee FROM employees WHERE id = NEW.exchange_partner_id;
            
            -- Perform bidirectional schedule swap
            SELECT swap_work_schedules_bidirectional(
                NEW.employee_id,           -- Requester
                NEW.exchange_partner_id,   -- Partner  
                NEW.exchange_from_date,    -- Date requester wants off
                NEW.exchange_to_date       -- Date partner wants off
            ) INTO swap_result;
            
            -- Create detailed notifications for both parties
            INSERT INTO notifications (employee_id, type, title, message, is_read) VALUES
            (NEW.employee_id, 'exchange_approved', 
             'Exchange Request Approved', 
             format('Your exchange request has been approved by admin. Schedule updated: You now have off on %s and work on %s. %s has off on %s and works on %s.',
                    NEW.exchange_from_date,
                    NEW.exchange_to_date,
                    partner_employee.name,
                    NEW.exchange_to_date,
                    NEW.exchange_from_date),
             false),
            (NEW.exchange_partner_id, 'exchange_approved', 
             'Exchange Request Approved', 
             format('The exchange request from %s has been approved by admin. Schedule updated: You now have off on %s and work on %s. %s has off on %s and works on %s.',
                    requester_employee.name,
                    NEW.exchange_to_date,
                    NEW.exchange_from_date,
                    requester_employee.name,
                    NEW.exchange_from_date,
                    NEW.exchange_to_date),
             false);
             
            -- Log the swap result
            RAISE NOTICE 'Bidirectional exchange completed: %', swap_result;
        END IF;
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- 4. Create or replace the trigger
DROP TRIGGER IF EXISTS trigger_update_schedule_on_approval ON requests;
CREATE TRIGGER trigger_update_schedule_on_approval
    AFTER UPDATE ON requests
    FOR EACH ROW
    EXECUTE FUNCTION update_request_status_and_schedules_bidirectional();

-- 5. Create a function to validate bidirectional exchange
CREATE OR REPLACE FUNCTION validate_bidirectional_exchange(
    p_requester_id BIGINT,
    p_partner_id BIGINT,
    p_requester_wants_off_date DATE,  -- Date requester wants to have off
    p_partner_wants_off_date DATE     -- Date partner wants to have off
) RETURNS JSONB AS $$
DECLARE
    requester_status_on_partner_date VARCHAR(20);
    partner_status_on_requester_date VARCHAR(20);
    requester_name VARCHAR(255);
    partner_name VARCHAR(255);
    result JSONB;
BEGIN
    -- Get employee names
    SELECT name INTO requester_name FROM employees WHERE id = p_requester_id;
    SELECT name INTO partner_name FROM employees WHERE id = p_partner_id;
    
    -- Check requester's status on the date they want off (should be working originally)
    requester_status_on_partner_date := get_work_schedule_status(p_requester_id, p_requester_wants_off_date);
    
    -- Check partner's status on the date they want off (should be working originally) 
    partner_status_on_requester_date := get_work_schedule_status(p_partner_id, p_partner_wants_off_date);
    
    -- Validate the exchange makes sense
    result := jsonb_build_object(
        'is_valid', true,
        'requester_name', requester_name,
        'partner_name', partner_name,
        'requester_wants_off_date', p_requester_wants_off_date,
        'partner_wants_off_date', p_partner_wants_off_date,
        'requester_current_status_on_wanted_off_date', requester_status_on_partner_date,
        'partner_current_status_on_wanted_off_date', partner_status_on_requester_date,
        'exchange_summary', format('%s wants off on %s (currently %s), %s wants off on %s (currently %s)',
                                   requester_name, p_requester_wants_off_date, requester_status_on_partner_date,
                                   partner_name, p_partner_wants_off_date, partner_status_on_requester_date)
    );
    
    -- Check if both dates are in the future
    IF p_requester_wants_off_date <= CURRENT_DATE OR p_partner_wants_off_date <= CURRENT_DATE THEN
        result := result || jsonb_build_object('is_valid', false, 'error', 'Exchange dates must be in the future');
        RETURN result;
    END IF;
    
    -- Ideally, we want one person to go from working → off and the other from off → working
    -- But we allow any exchange as long as it's different statuses
    IF requester_status_on_partner_date = partner_status_on_requester_date THEN
        result := result || jsonb_build_object(
            'warning', format('Both employees have the same status (%s) on their respective dates. This exchange may not provide the desired benefit.', requester_status_on_partner_date)
        );
    END IF;
    
    RETURN result;
END;
$$ LANGUAGE plpgsql;

-- 6. Create a function to show the current state of all exchange requests
CREATE OR REPLACE FUNCTION show_exchange_requests_status()
RETURNS TABLE(
    request_id BIGINT,
    requester_name VARCHAR(255),
    partner_name VARCHAR(255), 
    status VARCHAR(50),
    requester_wants_off_date DATE,
    partner_wants_off_date DATE,
    partner_approved BOOLEAN,
    workflow_status TEXT
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        r.id,
        r.employee_name,
        e.name as partner_name,
        r.status,
        r.exchange_from_date,
        r.exchange_to_date,
        r.exchange_partner_approved,
        CASE 
            WHEN r.exchange_partner_id IS NULL THEN 'Not an exchange request'
            WHEN r.exchange_partner_approved IS NULL THEN 'Waiting for partner approval'
            WHEN r.exchange_partner_approved = false THEN 'Partner rejected'
            WHEN r.exchange_partner_approved = true AND r.status = 'Partner Approved' THEN 'Ready for admin approval'
            WHEN r.status = 'Approved' THEN 'Approved - schedules swapped'
            WHEN r.status = 'Rejected' THEN 'Rejected by admin'
            ELSE 'Unknown status'
        END as workflow_status
    FROM requests r
    LEFT JOIN employees e ON e.id = r.exchange_partner_id
    WHERE r.type = 'Exchange Off Days'
    ORDER BY r.created_at DESC;
END;
$$ LANGUAGE plpgsql;

-- 7. Test the system
SELECT 'Testing Bidirectional Exchange System' as test_header;
SELECT * FROM show_exchange_requests_status();

COMMIT; 