-- Migration: Add vacation balance columns to employees table
-- Run this script in your Supabase SQL Editor if you have an existing database

-- Add vacation balance columns to employees table
ALTER TABLE employees 
ADD COLUMN IF NOT EXISTS annual_leave_remaining INTEGER DEFAULT 15,
ADD COLUMN IF NOT EXISTS sick_leave_remaining INTEGER DEFAULT 10;

-- Update existing employees with default values if columns were just added
UPDATE employees 
SET 
  annual_leave_remaining = 15,
  sick_leave_remaining = 10
WHERE annual_leave_remaining IS NULL OR sick_leave_remaining IS NULL;

-- Add admin policy for employee management if it doesn't exist
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies 
    WHERE tablename = 'employees' 
    AND policyname = 'Admin can manage employees'
  ) THEN
    CREATE POLICY "Admin can manage employees" ON employees
      FOR ALL USING (true);
  END IF;
END $$; 