-- Enhanced Work Schedule System with Automation and Recurring Templates
-- Run this script in your Supabase SQL Editor

-- Create work_schedule_templates table for recurring weekly off days
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
  is_active BOOLEAN DEFAULT TRUE,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  UNIQUE(employee_id)
);

-- Create indexes for better performance
CREATE INDEX IF NOT EXISTS idx_work_schedule_templates_employee_id ON work_schedule_templates(employee_id);
CREATE INDEX IF NOT EXISTS idx_work_schedule_templates_active ON work_schedule_templates(is_active);

-- Enable Row Level Security
ALTER TABLE work_schedule_templates ENABLE ROW LEVEL SECURITY;

-- Create policies for work_schedule_templates table
CREATE POLICY "Employees can view their own template" ON work_schedule_templates
  FOR SELECT USING (
    employee_id IN (
      SELECT id FROM employees WHERE email = current_user
    )
  );

CREATE POLICY "Admin can manage all templates" ON work_schedule_templates
  FOR ALL USING (true);

-- Create trigger to update updated_at timestamp
CREATE OR REPLACE FUNCTION update_work_schedule_template_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_update_work_schedule_template_updated_at
  BEFORE UPDATE ON work_schedule_templates
  FOR EACH ROW
  EXECUTE FUNCTION update_work_schedule_template_updated_at();

-- Function to get or create work schedule for a specific week
CREATE OR REPLACE FUNCTION get_or_create_work_schedule(
  p_employee_id BIGINT,
  p_week_start_date DATE
) RETURNS BIGINT AS $$
DECLARE
  schedule_id BIGINT;
  template_record RECORD;
BEGIN
  -- Check if schedule already exists for this week
  SELECT id INTO schedule_id
  FROM work_schedules
  WHERE employee_id = p_employee_id AND week_start_date = p_week_start_date;
  
  -- If schedule doesn't exist, create it from template
  IF schedule_id IS NULL THEN
    -- Get the employee's template
    SELECT * INTO template_record
    FROM work_schedule_templates
    WHERE employee_id = p_employee_id AND is_active = TRUE;
    
    -- If no template exists, create default template
    IF template_record IS NULL THEN
      INSERT INTO work_schedule_templates (
        employee_id, monday_status, tuesday_status, wednesday_status, 
        thursday_status, friday_status, saturday_status, sunday_status
      ) VALUES (
        p_employee_id, 'working', 'working', 'working', 'working', 'working', 'off', 'off'
      );
      
      SELECT * INTO template_record
      FROM work_schedule_templates
      WHERE employee_id = p_employee_id AND is_active = TRUE;
    END IF;
    
    -- Create schedule from template
    INSERT INTO work_schedules (
      employee_id, week_start_date, monday_status, tuesday_status, wednesday_status,
      thursday_status, friday_status, saturday_status, sunday_status
    ) VALUES (
      p_employee_id, p_week_start_date, template_record.monday_status, template_record.tuesday_status,
      template_record.wednesday_status, template_record.thursday_status, template_record.friday_status,
      template_record.saturday_status, template_record.sunday_status
    ) RETURNING id INTO schedule_id;
  END IF;
  
  RETURN schedule_id;
END;
$$ LANGUAGE plpgsql;

-- Enhanced function to get employee's day status for any date
CREATE OR REPLACE FUNCTION get_employee_day_status(
  p_employee_id BIGINT,
  p_date DATE
) RETURNS VARCHAR(20) AS $$
DECLARE
  week_start DATE;
  day_of_week INTEGER;
  day_status VARCHAR(20);
  schedule_id BIGINT;
BEGIN
  -- Get the start of the week (Monday) for the given date
  week_start := p_date - EXTRACT(DOW FROM p_date)::INTEGER + 1;
  
  -- Get day of week (0=Sunday, 1=Monday, ..., 6=Saturday)
  day_of_week := EXTRACT(DOW FROM p_date)::INTEGER;
  
  -- Ensure schedule exists for this week
  schedule_id := get_or_create_work_schedule(p_employee_id, week_start);
  
  -- Get the status for the specific day
  SELECT 
    CASE day_of_week
      WHEN 1 THEN monday_status
      WHEN 2 THEN tuesday_status
      WHEN 3 THEN wednesday_status
      WHEN 4 THEN thursday_status
      WHEN 5 THEN friday_status
      WHEN 6 THEN saturday_status
      WHEN 0 THEN sunday_status
    END INTO day_status
  FROM work_schedules 
  WHERE id = schedule_id;
  
  -- Return 'working' as default if no schedule found
  RETURN COALESCE(day_status, 'working');
END;
$$ LANGUAGE plpgsql;

-- Function to automatically update work schedule when leave request is approved
CREATE OR REPLACE FUNCTION update_schedule_for_approved_leave()
RETURNS TRIGGER AS $$
DECLARE
  week_start DATE;
  schedule_id BIGINT;
  current_date DATE;
  day_column VARCHAR(20);
  day_of_week INTEGER;
BEGIN
  -- Only process if status changed to 'Approved'
  IF NEW.status = 'Approved' AND (OLD.status IS NULL OR OLD.status != 'Approved') THEN
    
    -- For regular leave requests (not exchange)
    IF NEW.type != 'Exchange Off Days' THEN
      -- Update each day of the leave period
      current_date := NEW.start_date;
      WHILE current_date <= NEW.end_date LOOP
        -- Get week start for this date
        week_start := current_date - EXTRACT(DOW FROM current_date)::INTEGER + 1;
        
        -- Ensure schedule exists
        schedule_id := get_or_create_work_schedule(NEW.employee_id, week_start);
        
        -- Get day of week and corresponding column
        day_of_week := EXTRACT(DOW FROM current_date)::INTEGER;
        day_column := CASE day_of_week
          WHEN 1 THEN 'monday_status'
          WHEN 2 THEN 'tuesday_status'
          WHEN 3 THEN 'wednesday_status'
          WHEN 4 THEN 'thursday_status'
          WHEN 5 THEN 'friday_status'
          WHEN 6 THEN 'saturday_status'
          WHEN 0 THEN 'sunday_status'
        END;
        
        -- Update the schedule to mark this day as 'off'
        EXECUTE format('UPDATE work_schedules SET %I = ''off'' WHERE id = $1', day_column)
        USING schedule_id;
        
        current_date := current_date + INTERVAL '1 day';
      END LOOP;
    END IF;
    
    -- For exchange requests
    IF NEW.type = 'Exchange Off Days' AND NEW.exchange_from_date IS NOT NULL AND NEW.exchange_to_date IS NOT NULL THEN
      -- Mark the original off day as working
      week_start := NEW.exchange_from_date - EXTRACT(DOW FROM NEW.exchange_from_date)::INTEGER + 1;
      schedule_id := get_or_create_work_schedule(NEW.employee_id, week_start);
      
      day_of_week := EXTRACT(DOW FROM NEW.exchange_from_date)::INTEGER;
      day_column := CASE day_of_week
        WHEN 1 THEN 'monday_status'
        WHEN 2 THEN 'tuesday_status'
        WHEN 3 THEN 'wednesday_status'
        WHEN 4 THEN 'thursday_status'
        WHEN 5 THEN 'friday_status'
        WHEN 6 THEN 'saturday_status'
        WHEN 0 THEN 'sunday_status'
      END;
      
      EXECUTE format('UPDATE work_schedules SET %I = ''working'' WHERE id = $1', day_column)
      USING schedule_id;
      
      -- Mark the new off day as off
      week_start := NEW.exchange_to_date - EXTRACT(DOW FROM NEW.exchange_to_date)::INTEGER + 1;
      schedule_id := get_or_create_work_schedule(NEW.employee_id, week_start);
      
      day_of_week := EXTRACT(DOW FROM NEW.exchange_to_date)::INTEGER;
      day_column := CASE day_of_week
        WHEN 1 THEN 'monday_status'
        WHEN 2 THEN 'tuesday_status'
        WHEN 3 THEN 'wednesday_status'
        WHEN 4 THEN 'thursday_status'
        WHEN 5 THEN 'friday_status'
        WHEN 6 THEN 'saturday_status'
        WHEN 0 THEN 'sunday_status'
      END;
      
      EXECUTE format('UPDATE work_schedules SET %I = ''off'' WHERE id = $1', day_column)
      USING schedule_id;
    END IF;
  END IF;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create trigger to automatically update work schedules when requests are approved
CREATE TRIGGER trigger_update_schedule_on_approval
  AFTER UPDATE ON requests
  FOR EACH ROW
  EXECUTE FUNCTION update_schedule_for_approved_leave();

-- Function to generate schedules for a specific week for all employees
CREATE OR REPLACE FUNCTION generate_week_schedules(p_week_start_date DATE)
RETURNS VOID AS $$
DECLARE
  employee_record RECORD;
  template_record RECORD;
BEGIN
  -- Loop through all employees
  FOR employee_record IN SELECT id FROM employees LOOP
    -- Check if schedule already exists for this week
    IF NOT EXISTS (
      SELECT 1 FROM work_schedules 
      WHERE employee_id = employee_record.id AND week_start_date = p_week_start_date
    ) THEN
      -- Get or create template for this employee
      SELECT * INTO template_record
      FROM work_schedule_templates
      WHERE employee_id = employee_record.id AND is_active = TRUE;
      
      -- If no template exists, create default template
      IF template_record IS NULL THEN
        INSERT INTO work_schedule_templates (
          employee_id, monday_status, tuesday_status, wednesday_status, 
          thursday_status, friday_status, saturday_status, sunday_status
        ) VALUES (
          employee_record.id, 'working', 'working', 'working', 'working', 'working', 'off', 'off'
        );
        
        SELECT * INTO template_record
        FROM work_schedule_templates
        WHERE employee_id = employee_record.id AND is_active = TRUE;
      END IF;
      
      -- Create schedule from template
      INSERT INTO work_schedules (
        employee_id, week_start_date, monday_status, tuesday_status, wednesday_status,
        thursday_status, friday_status, saturday_status, sunday_status
      ) VALUES (
        employee_record.id, p_week_start_date, template_record.monday_status, template_record.tuesday_status,
        template_record.wednesday_status, template_record.thursday_status, template_record.friday_status,
        template_record.saturday_status, template_record.sunday_status
      );
    END IF;
  END LOOP;
END;
$$ LANGUAGE plpgsql;

-- Function to get available coverage for a specific date (enhanced)
CREATE OR REPLACE FUNCTION get_available_coverage(
  p_date DATE
) RETURNS TABLE(
  employee_id BIGINT,
  employee_name VARCHAR(255),
  employee_email VARCHAR(255),
  day_status VARCHAR(20)
) AS $$
BEGIN
  RETURN QUERY
  SELECT 
    e.id,
    e.name,
    e.email,
    get_employee_day_status(e.id, p_date) as day_status
  FROM employees e
  WHERE get_employee_day_status(e.id, p_date) = 'off'
  ORDER BY e.name;
END;
$$ LANGUAGE plpgsql;

-- Insert default templates for existing employees
INSERT INTO work_schedule_templates (employee_id, monday_status, tuesday_status, wednesday_status, thursday_status, friday_status, saturday_status, sunday_status)
SELECT 
  e.id,
  'working' as monday_status,
  'working' as tuesday_status,
  'working' as wednesday_status,
  'working' as thursday_status,
  'working' as friday_status,
  'off' as saturday_status,
  'off' as sunday_status
FROM employees e
WHERE NOT EXISTS (
  SELECT 1 FROM work_schedule_templates wt 
  WHERE wt.employee_id = e.id
);

-- Add comments for documentation
COMMENT ON TABLE work_schedule_templates IS 'Recurring weekly work schedule templates for employees';
COMMENT ON COLUMN work_schedule_templates.monday_status IS 'Default status for Monday: working or off';
COMMENT ON COLUMN work_schedule_templates.tuesday_status IS 'Default status for Tuesday: working or off';
COMMENT ON COLUMN work_schedule_templates.wednesday_status IS 'Default status for Wednesday: working or off';
COMMENT ON COLUMN work_schedule_templates.thursday_status IS 'Default status for Thursday: working or off';
COMMENT ON COLUMN work_schedule_templates.friday_status IS 'Default status for Friday: working or off';
COMMENT ON COLUMN work_schedule_templates.saturday_status IS 'Default status for Saturday: working or off';
COMMENT ON COLUMN work_schedule_templates.sunday_status IS 'Default status for Sunday: working or off';
COMMENT ON COLUMN work_schedule_templates.is_active IS 'Whether this template is currently active';

COMMENT ON FUNCTION get_or_create_work_schedule IS 'Gets existing work schedule or creates new one from template';
COMMENT ON FUNCTION update_schedule_for_approved_leave IS 'Automatically updates work schedules when leave requests are approved';
COMMENT ON FUNCTION generate_week_schedules IS 'Generates work schedules for all employees for a specific week';
