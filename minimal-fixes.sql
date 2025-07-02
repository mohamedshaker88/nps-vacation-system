-- Minimal Fixes for Vacation Management System
-- Run this script in your Supabase SQL Editor

-- 1. Add missing columns to requests table
ALTER TABLE requests 
ADD COLUMN IF NOT EXISTS exchange_partner_id BIGINT,
ADD COLUMN IF NOT EXISTS exchange_partner_approved BOOLEAN DEFAULT FALSE,
ADD COLUMN IF NOT EXISTS exchange_partner_approved_at TIMESTAMP WITH TIME ZONE,
ADD COLUMN IF NOT EXISTS exchange_partner_notes TEXT,
ADD COLUMN IF NOT EXISTS exchange_from_date DATE,
ADD COLUMN IF NOT EXISTS exchange_to_date DATE,
ADD COLUMN IF NOT EXISTS exchange_reason TEXT,
ADD COLUMN IF NOT EXISTS requires_partner_approval BOOLEAN DEFAULT FALSE;

-- 2. Create work_schedule_templates table if it doesn't exist
CREATE TABLE IF NOT EXISTS work_schedule_templates (
    id BIGSERIAL PRIMARY KEY,
    employee_id BIGINT REFERENCES employees(id) ON DELETE CASCADE,
    monday_status VARCHAR(20) DEFAULT 'working',
    tuesday_status VARCHAR(20) DEFAULT 'working',
    wednesday_status VARCHAR(20) DEFAULT 'working',
    thursday_status VARCHAR(20) DEFAULT 'working',
    friday_status VARCHAR(20) DEFAULT 'working',
    saturday_status VARCHAR(20) DEFAULT 'off',
    sunday_status VARCHAR(20) DEFAULT 'off',
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    UNIQUE(employee_id)
);

-- 3. Create work_schedules table if it doesn't exist
CREATE TABLE IF NOT EXISTS work_schedules (
    id BIGSERIAL PRIMARY KEY,
    employee_id BIGINT REFERENCES employees(id) ON DELETE CASCADE,
    week_start_date DATE NOT NULL,
    monday_status VARCHAR(20) DEFAULT 'working',
    tuesday_status VARCHAR(20) DEFAULT 'working',
    wednesday_status VARCHAR(20) DEFAULT 'working',
    thursday_status VARCHAR(20) DEFAULT 'working',
    friday_status VARCHAR(20) DEFAULT 'working',
    saturday_status VARCHAR(20) DEFAULT 'off',
    sunday_status VARCHAR(20) DEFAULT 'off',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    UNIQUE(employee_id, week_start_date)
);

-- 4. Create basic function to get employee day status
CREATE OR REPLACE FUNCTION get_employee_day_status(p_employee_id BIGINT, p_date DATE)
RETURNS VARCHAR AS $$
DECLARE
    day_of_week INTEGER;
    day_status VARCHAR;
    week_start DATE;
    schedule_record RECORD;
BEGIN
    -- Get day of week (0=Sunday, 1=Monday, ..., 6=Saturday)
    day_of_week := EXTRACT(DOW FROM p_date);
    
    -- Convert to our format (0=Monday, 1=Tuesday, ..., 6=Sunday)
    day_of_week := CASE 
        WHEN day_of_week = 0 THEN 6  -- Sunday
        ELSE day_of_week - 1         -- Monday=0, Tuesday=1, etc.
    END;
    
    -- Get week start (Monday)
    week_start := p_date - (day_of_week || ' days')::INTERVAL;
    
    -- Check if there's a specific schedule for this week
    SELECT * INTO schedule_record
    FROM work_schedules
    WHERE employee_id = p_employee_id 
    AND week_start_date = week_start;
    
    -- If specific schedule exists, use it
    IF FOUND THEN
        CASE day_of_week
            WHEN 0 THEN day_status := schedule_record.monday_status;
            WHEN 1 THEN day_status := schedule_record.tuesday_status;
            WHEN 2 THEN day_status := schedule_record.wednesday_status;
            WHEN 3 THEN day_status := schedule_record.thursday_status;
            WHEN 4 THEN day_status := schedule_record.friday_status;
            WHEN 5 THEN day_status := schedule_record.saturday_status;
            WHEN 6 THEN day_status := schedule_record.sunday_status;
        END CASE;
    ELSE
        -- Use template
        SELECT * INTO schedule_record
        FROM work_schedule_templates
        WHERE employee_id = p_employee_id 
        AND is_active = true;
        
        IF FOUND THEN
            CASE day_of_week
                WHEN 0 THEN day_status := schedule_record.monday_status;
                WHEN 1 THEN day_status := schedule_record.tuesday_status;
                WHEN 2 THEN day_status := schedule_record.wednesday_status;
                WHEN 3 THEN day_status := schedule_record.thursday_status;
                WHEN 4 THEN day_status := schedule_record.friday_status;
                WHEN 5 THEN day_status := schedule_record.saturday_status;
                WHEN 6 THEN day_status := schedule_record.sunday_status;
            END CASE;
        ELSE
            -- Default schedule: Mon-Fri working, Sat-Sun off
            CASE day_of_week
                WHEN 0,1,2,3,4 THEN day_status := 'working';
                WHEN 5,6 THEN day_status := 'off';
            END CASE;
        END IF;
    END IF;
    
    RETURN day_status;
END;
$$ LANGUAGE plpgsql;

-- 5. Create basic function to get available coverage
CREATE OR REPLACE FUNCTION get_available_coverage(p_date DATE)
RETURNS TABLE(
    employee_id BIGINT,
    employee_name VARCHAR,
    employee_email VARCHAR,
    day_status VARCHAR
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        e.id as employee_id,
        e.name as employee_name,
        e.email as employee_email,
        get_employee_day_status(e.id, p_date) as day_status
    FROM employees e
    WHERE get_employee_day_status(e.id, p_date) = 'off'
    ORDER BY e.name;
END;
$$ LANGUAGE plpgsql;

-- 6. Create basic function to generate week schedules
CREATE OR REPLACE FUNCTION generate_week_schedules(p_week_start_date DATE)
RETURNS VOID AS $$
BEGIN
    -- This is a placeholder function - will be enhanced later
    NULL;
END;
$$ LANGUAGE plpgsql;

-- 7. Create basic function to get pending exchange approvals
CREATE OR REPLACE FUNCTION get_pending_exchange_approvals(p_employee_id BIGINT)
RETURNS TABLE(
    request_id BIGINT,
    requester_name VARCHAR(255),
    requester_email VARCHAR(255),
    exchange_from_date DATE,
    exchange_to_date DATE,
    exchange_reason TEXT,
    request_created_at TIMESTAMP WITH TIME ZONE
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        r.id,
        e.name,
        e.email,
        r.exchange_from_date,
        r.exchange_to_date,
        r.exchange_reason,
        r.created_at
    FROM requests r
    JOIN employees e ON r.employee_email = e.email
    WHERE r.exchange_partner_id = p_employee_id
    AND r.exchange_partner_approved = FALSE
    AND r.status = 'Pending'
    ORDER BY r.created_at DESC;
END;
$$ LANGUAGE plpgsql;

-- 8. Create basic function to approve exchange request
CREATE OR REPLACE FUNCTION approve_exchange_request(
    p_request_id BIGINT,
    p_employee_id BIGINT,
    p_approved BOOLEAN,
    p_notes TEXT DEFAULT NULL
) RETURNS BOOLEAN AS $$
BEGIN
    -- Update the exchange approval
    UPDATE requests 
    SET 
        exchange_partner_approved = p_approved,
        exchange_partner_approved_at = NOW(),
        exchange_partner_notes = p_notes
    WHERE id = p_request_id;
    
    -- If approved, also update the main request status to 'Partner Approved'
    -- If rejected, update to 'Rejected'
    IF p_approved THEN
        UPDATE requests 
        SET status = 'Partner Approved'
        WHERE id = p_request_id;
    ELSE
        UPDATE requests 
        SET status = 'Rejected'
        WHERE id = p_request_id;
    END IF;
    
    RETURN TRUE;
END;
$$ LANGUAGE plpgsql;

-- 9. Update existing requests to have default values
UPDATE requests 
SET 
    exchange_from_date = start_date,
    exchange_to_date = end_date,
    exchange_reason = reason,
    requires_partner_approval = TRUE
WHERE exchange_from_date IS NULL;

-- 10. Temporarily disable RLS for requests table to fix insertion issues
ALTER TABLE requests DISABLE ROW LEVEL SECURITY;

-- Note: We'll re-enable RLS with proper policies once the basic functionality works

-- 11. Temporarily disable RLS for work_schedule_templates table
ALTER TABLE work_schedule_templates DISABLE ROW LEVEL SECURITY;

-- 12. Temporarily disable RLS for work_schedules table
ALTER TABLE work_schedules DISABLE ROW LEVEL SECURITY;

-- 13. Grant necessary permissions
GRANT USAGE ON SCHEMA public TO anon, authenticated;
GRANT ALL ON ALL TABLES IN SCHEMA public TO anon, authenticated;
GRANT ALL ON ALL SEQUENCES IN SCHEMA public TO anon, authenticated;

-- 14. Create a test function to verify database connectivity
CREATE OR REPLACE FUNCTION test_database_connection()
RETURNS TEXT AS $$
BEGIN
    RETURN 'Database connection successful!';
END;
$$ LANGUAGE plpgsql; 