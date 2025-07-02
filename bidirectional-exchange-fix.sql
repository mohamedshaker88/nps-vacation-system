-- True Bidirectional Exchange Fix
-- This fixes the exchange system to properly swap schedules between both employees

-- 1. Create bidirectional swap function
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

-- 2. Update the admin approval trigger to use bidirectional swap
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

-- 3. Create or replace the trigger
DROP TRIGGER IF EXISTS trigger_update_schedule_on_approval ON requests;
CREATE TRIGGER trigger_update_schedule_on_approval
    AFTER UPDATE ON requests
    FOR EACH ROW
    EXECUTE FUNCTION update_request_status_and_schedules_bidirectional();

-- 4. Create a function to show the current state of all exchange requests
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

-- 5. Test the system
SELECT 'Testing Bidirectional Exchange System' as test_header;
SELECT * FROM show_exchange_requests_status();

COMMIT; 