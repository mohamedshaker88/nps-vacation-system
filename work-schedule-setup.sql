-- Create work_schedule_templates table
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

-- Create work_schedules table for actual weekly schedules
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

-- Create indexes for better performance
CREATE INDEX IF NOT EXISTS idx_work_schedule_templates_employee ON work_schedule_templates(employee_id);
CREATE INDEX IF NOT EXISTS idx_work_schedule_templates_active ON work_schedule_templates(is_active);
CREATE INDEX IF NOT EXISTS idx_work_schedules_employee ON work_schedules(employee_id);
CREATE INDEX IF NOT EXISTS idx_work_schedules_week ON work_schedules(week_start_date);

-- Function to get employee day status
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

-- Function to generate week schedules from templates
CREATE OR REPLACE FUNCTION generate_week_schedules(p_week_start_date DATE)
RETURNS VOID AS $$
DECLARE
    template_record RECORD;
    new_schedule RECORD;
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

-- Function to get available coverage for a specific date
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

-- Update trigger for work_schedule_templates
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

-- Update trigger for work_schedules
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