-- Work Schedule System for NPS Vacation Management
-- Run this script in your Supabase SQL Editor

-- Create work_schedules table
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
CREATE INDEX IF NOT EXISTS idx_work_schedules_employee_id ON work_schedules(employee_id);
CREATE INDEX IF NOT EXISTS idx_work_schedules_week_start ON work_schedules(week_start_date);
CREATE INDEX IF NOT EXISTS idx_work_schedules_employee_week ON work_schedules(employee_id, week_start_date);

-- Enable Row Level Security
ALTER TABLE work_schedules ENABLE ROW LEVEL SECURITY;

-- Create policies for work_schedules table
CREATE POLICY "Employees can view their own schedule" ON work_schedules
  FOR SELECT USING (
    employee_id IN (
      SELECT id FROM employees WHERE email = current_user
    )
  );

CREATE POLICY "Admin can manage all schedules" ON work_schedules
  FOR ALL USING (true);

-- Create function to get employee's day status for any date
CREATE OR REPLACE FUNCTION get_employee_day_status(
  p_employee_id BIGINT,
  p_date DATE
) RETURNS VARCHAR(20) AS $$
DECLARE
  week_start DATE;
  day_of_week INTEGER;
  day_status VARCHAR(20);
BEGIN
  -- Get the start of the week (Monday) for the given date
  week_start := p_date - EXTRACT(DOW FROM p_date)::INTEGER + 1;
  
  -- Get day of week (0=Sunday, 1=Monday, ..., 6=Saturday)
  day_of_week := EXTRACT(DOW FROM p_date)::INTEGER;
  
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
  WHERE employee_id = p_employee_id 
    AND week_start_date = week_start;
  
  -- Return 'working' as default if no schedule found
  RETURN COALESCE(day_status, 'working');
END;
$$ LANGUAGE plpgsql;

-- Create function to get available coverage for a specific date
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

-- Create trigger to update updated_at timestamp
CREATE OR REPLACE FUNCTION update_work_schedule_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_update_work_schedule_updated_at
  BEFORE UPDATE ON work_schedules
  FOR EACH ROW
  EXECUTE FUNCTION update_work_schedule_updated_at();

-- Insert sample work schedules for existing employees
INSERT INTO work_schedules (employee_id, week_start_date, monday_status, tuesday_status, wednesday_status, thursday_status, friday_status, saturday_status, sunday_status)
SELECT 
  e.id,
  DATE_TRUNC('week', CURRENT_DATE)::DATE as week_start_date,
  'working' as monday_status,
  'working' as tuesday_status,
  'working' as wednesday_status,
  'working' as thursday_status,
  'working' as friday_status,
  'off' as saturday_status,
  'off' as sunday_status
FROM employees e
WHERE NOT EXISTS (
  SELECT 1 FROM work_schedules ws 
  WHERE ws.employee_id = e.id 
    AND ws.week_start_date = DATE_TRUNC('week', CURRENT_DATE)::DATE
);

-- Add comments for documentation
COMMENT ON TABLE work_schedules IS 'Employee work schedules showing working days vs off days';
COMMENT ON COLUMN work_schedules.week_start_date IS 'Start date of the week (Monday)';
COMMENT ON COLUMN work_schedules.monday_status IS 'Status for Monday: working or off';
COMMENT ON COLUMN work_schedules.tuesday_status IS 'Status for Tuesday: working or off';
COMMENT ON COLUMN work_schedules.wednesday_status IS 'Status for Wednesday: working or off';
COMMENT ON COLUMN work_schedules.thursday_status IS 'Status for Thursday: working or off';
COMMENT ON COLUMN work_schedules.friday_status IS 'Status for Friday: working or off';
COMMENT ON COLUMN work_schedules.saturday_status IS 'Status for Saturday: working or off';
COMMENT ON COLUMN work_schedules.sunday_status IS 'Status for Sunday: working or off'; 