-- Comprehensive Fixes for Vacation Management System
-- Run this script in your Supabase SQL Editor

-- 1. Fix requests table - add missing columns
ALTER TABLE requests 
ADD COLUMN IF NOT EXISTS exchange_partner_id BIGINT REFERENCES employees(id),
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
    monday_status VARCHAR(20) DEFAULT 'working' CHECK (monday_status IN ('working', 'off')),
    tuesday_status VARCHAR(20) DEFAULT 'working' CHECK (tuesday_status IN ('working', 'off')),
    wednesday_status VARCHAR(20) DEFAULT 'working' CHECK (wednesday_status IN ('working', 'off')),
    thursday_status VARCHAR(20) DEFAULT 'working' CHECK (thursday_status IN ('working', 'off')),
    friday_status VARCHAR(20) DEFAULT 'working' CHECK (friday_status IN ('working', 'off')),
    saturday_status VARCHAR(20) DEFAULT 'off' CHECK (saturday_status IN ('working', 'off')),
    sunday_status VARCHAR(20) DEFAULT 'off' CHECK (sunday_status IN ('working', 'off')),
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
    monday_status VARCHAR(20) DEFAULT 'working' CHECK (monday_status IN ('working', 'off')),
    tuesday_status VARCHAR(20) DEFAULT 'working' CHECK (tuesday_status IN ('working', 'off')),
    wednesday_status VARCHAR(20) DEFAULT 'working' CHECK (wednesday_status IN ('working', 'off')),
    thursday_status VARCHAR(20) DEFAULT 'working' CHECK (thursday_status IN ('working', 'off')),
    friday_status VARCHAR(20) DEFAULT 'working' CHECK (friday_status IN ('working', 'off')),
    saturday_status VARCHAR(20) DEFAULT 'off' CHECK (saturday_status IN ('working', 'off')),
    sunday_status VARCHAR(20) DEFAULT 'off' CHECK (sunday_status IN ('working', 'off')),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    UNIQUE(employee_id, week_start_date)
);

-- 4. Create notifications table for exchange partner notifications
CREATE TABLE IF NOT EXISTS notifications (
    id BIGSERIAL PRIMARY KEY,
    employee_id BIGINT REFERENCES employees(id) ON DELETE CASCADE,
    request_id BIGINT REFERENCES requests(id) ON DELETE CASCADE,
    type VARCHAR(50) NOT NULL, -- 'exchange_approval', 'request_approved', 'request_rejected'
    title VARCHAR(255) NOT NULL,
    message TEXT NOT NULL,
    is_read BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 5. Create indexes for better performance
CREATE INDEX IF NOT EXISTS idx_requests_exchange_partner ON requests(exchange_partner_id);
CREATE INDEX IF NOT EXISTS idx_requests_requires_approval ON requests(requires_partner_approval);
CREATE INDEX IF NOT EXISTS idx_work_schedule_templates_employee ON work_schedule_templates(employee_id);
CREATE INDEX IF NOT EXISTS idx_work_schedule_templates_active ON work_schedule_templates(is_active);
CREATE INDEX IF NOT EXISTS idx_work_schedules_employee ON work_schedules(employee_id);
CREATE INDEX IF NOT EXISTS idx_work_schedules_week ON work_schedules(week_start_date);
CREATE INDEX IF NOT EXISTS idx_notifications_employee ON notifications(employee_id);
CREATE INDEX IF NOT EXISTS idx_notifications_read ON notifications(is_read);

-- 6. Function to get employee day status
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
            -- Default schedule
            CASE day_of_week
                WHEN 0,1,2,3,4 THEN day_status := 'working';
                WHEN 5,6 THEN day_status := 'off';
            END CASE;
        END IF;
    END IF;
    
    RETURN day_status;
END;
$$ LANGUAGE plpgsql;

-- 7. Function to get available coverage
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

-- 8. Function to generate week schedules from templates
CREATE OR REPLACE FUNCTION generate_week_schedules(p_week_start_date DATE)
RETURNS VOID AS $$
DECLARE
    template_record RECORD;
BEGIN
    -- Loop through all active templates
    FOR template_record IN 
        SELECT * FROM work_schedule_templates WHERE is_active = true
    LOOP
        -- Check if schedule already exists for this week
        IF NOT EXISTS (
            SELECT 1 FROM work_schedules 
            WHERE employee_id = template_record.employee_id 
            AND week_start_date = p_week_start_date
        ) THEN
            -- Insert new schedule based on template
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
                template_record.employee_id,
                p_week_start_date,
                template_record.monday_status,
                template_record.tuesday_status,
                template_record.wednesday_status,
                template_record.thursday_status,
                template_record.friday_status,
                template_record.saturday_status,
                template_record.sunday_status
            );
        END IF;
    END LOOP;
END;
$$ LANGUAGE plpgsql;

-- 9. Function to get pending exchange approvals
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

-- 10. Function to approve exchange request
CREATE OR REPLACE FUNCTION approve_exchange_request(
    p_request_id BIGINT,
    p_employee_id BIGINT,
    p_approved BOOLEAN,
    p_notes TEXT DEFAULT NULL
) RETURNS BOOLEAN AS $$
BEGIN
    -- Check if the employee is the exchange partner for this request
    IF NOT EXISTS (
        SELECT 1 FROM requests 
        WHERE id = p_request_id 
        AND exchange_partner_id = p_employee_id
        AND exchange_partner_approved = FALSE
    ) THEN
        RETURN FALSE;
    END IF;
    
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

-- 11. Function to create notification for exchange partner
CREATE OR REPLACE FUNCTION create_exchange_notification(
    p_request_id BIGINT,
    p_exchange_partner_id BIGINT
) RETURNS VOID AS $$
DECLARE
    request_record RECORD;
BEGIN
    -- Get request details
    SELECT * INTO request_record
    FROM requests
    WHERE id = p_request_id;
    
    -- Create notification
    INSERT INTO notifications (
        employee_id,
        request_id,
        type,
        title,
        message
    ) VALUES (
        p_exchange_partner_id,
        p_request_id,
        'exchange_approval',
        'Exchange Request Requires Your Approval',
        'You have been selected as an exchange partner for a leave request. Please review and approve/reject the request.'
    );
END;
$$ LANGUAGE plpgsql;

-- 12. Trigger to create notification when exchange request is created
CREATE OR REPLACE FUNCTION trigger_create_exchange_notification()
RETURNS TRIGGER AS $$
BEGIN
    -- If this is an exchange request with a partner, create notification
    IF NEW.exchange_partner_id IS NOT NULL AND NEW.requires_partner_approval = TRUE THEN
        PERFORM create_exchange_notification(NEW.id, NEW.exchange_partner_id);
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create trigger
DROP TRIGGER IF EXISTS trigger_exchange_notification ON requests;
CREATE TRIGGER trigger_exchange_notification
    AFTER INSERT ON requests
    FOR EACH ROW
    EXECUTE FUNCTION trigger_create_exchange_notification();

-- 13. Update triggers for timestamps
CREATE OR REPLACE FUNCTION update_work_schedule_templates_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_update_work_schedule_templates_updated_at
    BEFORE UPDATE ON work_schedule_templates
    FOR EACH ROW
    EXECUTE FUNCTION update_work_schedule_templates_updated_at();

CREATE OR REPLACE FUNCTION update_work_schedules_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_update_work_schedules_updated_at
    BEFORE UPDATE ON work_schedules
    FOR EACH ROW
    EXECUTE FUNCTION update_work_schedules_updated_at();

-- 14. Update existing requests to have default values
UPDATE requests 
SET 
    exchange_from_date = start_date,
    exchange_to_date = end_date,
    exchange_reason = reason,
    requires_partner_approval = TRUE
WHERE exchange_from_date IS NULL;

-- 15. Create RLS policies for notifications
ALTER TABLE notifications ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Employees can view their own notifications" ON notifications
    FOR SELECT USING (employee_id IN (
        SELECT id FROM employees WHERE email = current_user
    ));

CREATE POLICY "Employees can update their own notifications" ON notifications
    FOR UPDATE USING (employee_id IN (
        SELECT id FROM employees WHERE email = current_user
    ));

-- 16. Grant necessary permissions
GRANT USAGE ON SCHEMA public TO anon, authenticated;
GRANT ALL ON ALL TABLES IN SCHEMA public TO anon, authenticated;
GRANT ALL ON ALL SEQUENCES IN SCHEMA public TO anon, authenticated; 