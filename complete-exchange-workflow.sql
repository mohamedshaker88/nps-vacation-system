-- Complete Exchange Workflow with Schedule Updates
-- Run this script in your Supabase SQL Editor

-- 1. Create function to get or create work schedule for a specific week
CREATE OR REPLACE FUNCTION get_or_create_work_schedule(
    p_employee_id BIGINT,
    p_week_start_date DATE
) RETURNS BIGINT AS $$
DECLARE
    schedule_id BIGINT;
    template_record RECORD;
BEGIN
    -- Try to get existing schedule
    SELECT id INTO schedule_id
    FROM work_schedules
    WHERE employee_id = p_employee_id 
    AND week_start_date = p_week_start_date;
    
    IF schedule_id IS NOT NULL THEN
        RETURN schedule_id;
    END IF;
    
    -- Get template for this employee
    SELECT * INTO template_record
    FROM work_schedule_templates
    WHERE employee_id = p_employee_id 
    AND is_active = true;
    
    -- Create schedule based on template or default
    INSERT INTO work_schedules (
        employee_id,
        week_start_date,
        monday_status,
        tuesday_status,
        wednesday_status,
        thursday_status,
        friday_status,
        saturday_status,
        sunday_status
    ) VALUES (
        p_employee_id,
        p_week_start_date,
        COALESCE(template_record.monday_status, 'working'),
        COALESCE(template_record.tuesday_status, 'working'),
        COALESCE(template_record.wednesday_status, 'working'),
        COALESCE(template_record.thursday_status, 'working'),
        COALESCE(template_record.friday_status, 'working'),
        COALESCE(template_record.saturday_status, 'off'),
        COALESCE(template_record.sunday_status, 'off')
    ) RETURNING id INTO schedule_id;
    
    RETURN schedule_id;
END;
$$ LANGUAGE plpgsql;

-- 2. Create function to update work schedule for approved exchange
CREATE OR REPLACE FUNCTION update_work_schedule_for_exchange(
    p_request_id BIGINT
) RETURNS VOID AS $$
DECLARE
    request_record RECORD;
    requester_id BIGINT;
    partner_id BIGINT;
    requester_from_week DATE;
    requester_to_week DATE;
    partner_from_week DATE;
    partner_to_week DATE;
    requester_from_schedule_id BIGINT;
    requester_to_schedule_id BIGINT;
    partner_from_schedule_id BIGINT;
    partner_to_schedule_id BIGINT;
    from_day_column VARCHAR(20);
    to_day_column VARCHAR(20);
    from_day_of_week INTEGER;
    to_day_of_week INTEGER;
BEGIN
    -- Get request details
    SELECT * INTO request_record
    FROM requests
    WHERE id = p_request_id;
    
    -- Get employee IDs
    SELECT id INTO requester_id
    FROM employees
    WHERE email = request_record.employee_email;
    
    partner_id := request_record.exchange_partner_id;
    
    -- Calculate week start dates (Monday)
    from_day_of_week := EXTRACT(DOW FROM request_record.exchange_from_date);
    to_day_of_week := EXTRACT(DOW FROM request_record.exchange_to_date);
    
    -- Convert Sunday (0) to 7 for proper calculation
    IF from_day_of_week = 0 THEN from_day_of_week := 7; END IF;
    IF to_day_of_week = 0 THEN to_day_of_week := 7; END IF;
    
    requester_from_week := request_record.exchange_from_date - (from_day_of_week - 1);
    requester_to_week := request_record.exchange_to_date - (to_day_of_week - 1);
    partner_from_week := request_record.exchange_from_date - (from_day_of_week - 1);
    partner_to_week := request_record.exchange_to_date - (to_day_of_week - 1);
    
    -- Get day column names
    from_day_column := CASE from_day_of_week
        WHEN 1 THEN 'monday_status'
        WHEN 2 THEN 'tuesday_status'
        WHEN 3 THEN 'wednesday_status'
        WHEN 4 THEN 'thursday_status'
        WHEN 5 THEN 'friday_status'
        WHEN 6 THEN 'saturday_status'
        WHEN 7 THEN 'sunday_status'
    END;
    
    to_day_column := CASE to_day_of_week
        WHEN 1 THEN 'monday_status'
        WHEN 2 THEN 'tuesday_status'
        WHEN 3 THEN 'wednesday_status'
        WHEN 4 THEN 'thursday_status'
        WHEN 5 THEN 'friday_status'
        WHEN 6 THEN 'saturday_status'
        WHEN 7 THEN 'sunday_status'
    END;
    
    -- Get or create work schedules
    requester_from_schedule_id := get_or_create_work_schedule(requester_id, requester_from_week);
    requester_to_schedule_id := get_or_create_work_schedule(requester_id, requester_to_week);
    partner_from_schedule_id := get_or_create_work_schedule(partner_id, partner_from_week);
    partner_to_schedule_id := get_or_create_work_schedule(partner_id, partner_to_week);
    
    -- Update requester's schedule: from off to working, to from working to off
    EXECUTE format('UPDATE work_schedules SET %I = ''working'' WHERE id = $1', from_day_column)
    USING requester_from_schedule_id;
    
    EXECUTE format('UPDATE work_schedules SET %I = ''off'' WHERE id = $1', to_day_column)
    USING requester_to_schedule_id;
    
    -- Update partner's schedule: from working to off, to from off to working
    EXECUTE format('UPDATE work_schedules SET %I = ''off'' WHERE id = $1', from_day_column)
    USING partner_from_schedule_id;
    
    EXECUTE format('UPDATE work_schedules SET %I = ''working'' WHERE id = $1', to_day_column)
    USING partner_to_schedule_id;
    
    RAISE NOTICE 'Updated work schedules for exchange request %', p_request_id;
    RAISE NOTICE 'Requester % (ID: %): % → working, % → off', 
                 request_record.employee_email, requester_id, 
                 request_record.exchange_from_date, request_record.exchange_to_date;
    RAISE NOTICE 'Partner % (ID: %): % → off, % → working',
                 (SELECT email FROM employees WHERE id = partner_id), partner_id,
                 request_record.exchange_from_date, request_record.exchange_to_date;
END;
$$ LANGUAGE plpgsql;

-- 3. Create trigger function for when admin approves exchange requests
CREATE OR REPLACE FUNCTION handle_exchange_approval()
RETURNS TRIGGER AS $$
BEGIN
    -- Only process when status changes to 'Approved'
    IF NEW.status = 'Approved' AND OLD.status != 'Approved' THEN
        -- If this is an exchange request
        IF NEW.exchange_partner_id IS NOT NULL AND NEW.exchange_from_date IS NOT NULL THEN
            -- Update work schedules
            PERFORM update_work_schedule_for_exchange(NEW.id);
            
            -- Create notifications for both parties
            INSERT INTO notifications (
                employee_id,
                request_id,
                type,
                title,
                message
            ) VALUES 
            (
                (SELECT id FROM employees WHERE email = NEW.employee_email),
                NEW.id,
                'request_approved',
                'Exchange Request Approved',
                'Your exchange request has been approved by the admin. Work schedules have been updated.'
            ),
            (
                NEW.exchange_partner_id,
                NEW.id,
                'request_approved',
                'Exchange Request Approved',
                'The exchange request you approved has been approved by the admin. Work schedules have been updated.'
            );
        END IF;
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- 4. Create the trigger
DROP TRIGGER IF EXISTS trigger_handle_exchange_approval ON requests;
CREATE TRIGGER trigger_handle_exchange_approval
    AFTER UPDATE ON requests
    FOR EACH ROW
    EXECUTE FUNCTION handle_exchange_approval();

-- 5. Update the admin approval check function
CREATE OR REPLACE FUNCTION can_admin_approve_request(p_request_id INTEGER)
RETURNS TABLE(can_approve BOOLEAN, reason TEXT, debug_info JSONB) AS $$
DECLARE
    request_row requests%ROWTYPE;
    debug_obj JSONB := '{}';
BEGIN
    -- Get the request details
    SELECT * INTO request_row FROM requests WHERE id = p_request_id;
    
    -- Build debug info
    debug_obj := jsonb_build_object(
        'request_id', p_request_id,
        'request_status', request_row.status,
        'exchange_partner_id', request_row.exchange_partner_id,
        'exchange_partner_approved', request_row.exchange_partner_approved,
        'exchange_partner_approved_at', request_row.exchange_partner_approved_at
    );
    
    -- If request doesn't exist
    IF request_row.id IS NULL THEN
        RETURN QUERY SELECT false, 'Request not found', debug_obj;
        RETURN;
    END IF;
    
    -- If request is already processed
    IF request_row.status IN ('Approved', 'Rejected') THEN
        RETURN QUERY SELECT false, 'Request already processed', debug_obj;
        RETURN;
    END IF;
    
    -- If it's not an exchange request, admin can approve
    IF request_row.exchange_partner_id IS NULL THEN
        RETURN QUERY SELECT true, 'Regular leave request - can approve', debug_obj;
        RETURN;
    END IF;
    
    -- For exchange requests, check partner approval
    IF request_row.exchange_partner_approved IS NULL THEN
        RETURN QUERY SELECT false, 'Waiting for exchange partner approval', debug_obj;
        RETURN;
    END IF;
    
    IF request_row.exchange_partner_approved = false THEN
        RETURN QUERY SELECT false, 'Exchange partner rejected the request', debug_obj;
        RETURN;
    END IF;
    
    -- Partner approved, admin can approve
    RETURN QUERY SELECT true, 'Exchange partner approved - admin can approve', debug_obj;
END;
$$ LANGUAGE plpgsql;

-- 6. Create function to get work schedule status for a date
CREATE OR REPLACE FUNCTION get_work_schedule_status(
    p_employee_id BIGINT,
    p_date DATE
) RETURNS VARCHAR AS $$
DECLARE
    day_of_week INTEGER;
    week_start DATE;
    schedule_record RECORD;
    day_status VARCHAR(20);
BEGIN
    -- Get day of week (1=Monday, 7=Sunday)
    day_of_week := EXTRACT(DOW FROM p_date);
    IF day_of_week = 0 THEN day_of_week := 7; END IF; -- Convert Sunday to 7
    
    -- Get week start (Monday)
    week_start := p_date - (day_of_week - 1);
    
    -- Get schedule for this week
    SELECT * INTO schedule_record
    FROM work_schedules
    WHERE employee_id = p_employee_id 
    AND week_start_date = week_start;
    
    IF FOUND THEN
        -- Get status for the specific day
        CASE day_of_week
            WHEN 1 THEN day_status := schedule_record.monday_status;
            WHEN 2 THEN day_status := schedule_record.tuesday_status;
            WHEN 3 THEN day_status := schedule_record.wednesday_status;
            WHEN 4 THEN day_status := schedule_record.thursday_status;
            WHEN 5 THEN day_status := schedule_record.friday_status;
            WHEN 6 THEN day_status := schedule_record.saturday_status;
            WHEN 7 THEN day_status := schedule_record.sunday_status;
        END CASE;
    ELSE
        -- Use template or default
        SELECT 
            CASE day_of_week
                WHEN 1 THEN monday_status
                WHEN 2 THEN tuesday_status
                WHEN 3 THEN wednesday_status
                WHEN 4 THEN thursday_status
                WHEN 5 THEN friday_status
                WHEN 6 THEN saturday_status
                WHEN 7 THEN sunday_status
            END INTO day_status
        FROM work_schedule_templates
        WHERE employee_id = p_employee_id 
        AND is_active = true;
        
        -- Default if no template
        IF day_status IS NULL THEN
            day_status := CASE 
                WHEN day_of_week IN (1,2,3,4,5) THEN 'working'
                ELSE 'off'
            END;
        END IF;
    END IF;
    
    RETURN day_status;
END;
$$ LANGUAGE plpgsql;

-- 7. Test the system with example data
SELECT '=== TESTING THE SYSTEM ===' as info;

-- Show current requests that need admin approval
SELECT 
    'Requests Ready for Admin Approval' as check_item,
    r.id,
    r.employee_name as requester,
    r.exchange_partner_id,
    e.name as partner_name,
    r.exchange_partner_approved,
    r.status,
    r.exchange_from_date,
    r.exchange_to_date
FROM requests r
LEFT JOIN employees e ON r.exchange_partner_id = e.id
WHERE r.exchange_partner_approved = TRUE
AND r.status = 'Partner Approved'
ORDER BY r.created_at DESC;

-- Update request status change to handle Partner Approved status correctly
CREATE OR REPLACE FUNCTION update_request_status_and_schedules()
RETURNS TRIGGER AS $$
DECLARE
    partner_employee employees%ROWTYPE;
    requester_employee employees%ROWTYPE;
BEGIN
    -- Only process when status changes to 'Approved'
    IF NEW.status = 'Approved' AND OLD.status != 'Approved' THEN
        -- If this is an exchange request, update work schedules
        IF NEW.exchange_partner_id IS NOT NULL THEN
            -- Get employee details
            SELECT * INTO requester_employee FROM employees WHERE id = NEW.employee_id;
            SELECT * INTO partner_employee FROM employees WHERE id = NEW.exchange_partner_id;
            
            -- Swap work schedules for the exchange date
            PERFORM swap_work_schedules_for_date(
                NEW.employee_id, 
                NEW.exchange_partner_id, 
                NEW.start_date::date
            );
            
            -- Create notifications for both parties
            INSERT INTO notifications (employee_id, type, title, message, is_read) VALUES
            (NEW.employee_id, 'exchange_approved', 
             'Exchange Request Approved', 
             'Your exchange request for ' || NEW.start_date || ' with ' || partner_employee.name || ' has been approved by admin. Work schedules have been updated.',
             false),
            (NEW.exchange_partner_id, 'exchange_approved', 
             'Exchange Request Approved', 
             'The exchange request from ' || requester_employee.name || ' for ' || NEW.start_date || ' has been approved by admin. Work schedules have been updated.',
             false);
        END IF;
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Also ensure we have a function to manually check partner approval status
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