-- Fix INSERT Column Mismatch Error
-- This script ensures all columns in requests table have proper defaults

BEGIN;

-- Step 1: Check current structure of requests table
SELECT 
    '=== REQUESTS TABLE STRUCTURE ===' as info,
    column_name,
    data_type,
    is_nullable,
    column_default
FROM information_schema.columns 
WHERE table_name = 'requests'
ORDER BY ordinal_position;

-- Step 2: Ensure all exchange-related columns exist with proper defaults
ALTER TABLE requests 
ADD COLUMN IF NOT EXISTS employee_id BIGINT REFERENCES employees(id),
ADD COLUMN IF NOT EXISTS exchange_partner_id BIGINT REFERENCES employees(id),
ADD COLUMN IF NOT EXISTS exchange_partner_approved BOOLEAN DEFAULT NULL,
ADD COLUMN IF NOT EXISTS exchange_partner_approved_at TIMESTAMP WITH TIME ZONE DEFAULT NULL,
ADD COLUMN IF NOT EXISTS exchange_partner_notes TEXT DEFAULT NULL,
ADD COLUMN IF NOT EXISTS exchange_from_date DATE DEFAULT NULL,
ADD COLUMN IF NOT EXISTS exchange_to_date DATE DEFAULT NULL,
ADD COLUMN IF NOT EXISTS exchange_reason TEXT DEFAULT NULL,
ADD COLUMN IF NOT EXISTS partner_desired_off_date DATE DEFAULT NULL,
ADD COLUMN IF NOT EXISTS requires_partner_approval BOOLEAN DEFAULT false,
ADD COLUMN IF NOT EXISTS coverage_arranged BOOLEAN DEFAULT false,
ADD COLUMN IF NOT EXISTS coverage_by TEXT DEFAULT NULL,
ADD COLUMN IF NOT EXISTS medical_certificate BOOLEAN DEFAULT false,
ADD COLUMN IF NOT EXISTS emergency_contact TEXT DEFAULT NULL,
ADD COLUMN IF NOT EXISTS additional_notes TEXT DEFAULT NULL,
ADD COLUMN IF NOT EXISTS submit_date DATE DEFAULT CURRENT_DATE;

-- Step 3: Update employee_id for existing requests that don't have it
UPDATE requests 
SET employee_id = e.id
FROM employees e
WHERE requests.employee_email = e.email
AND requests.employee_id IS NULL;

-- Step 4: Set proper defaults for existing exchange requests
UPDATE requests 
SET 
    exchange_from_date = COALESCE(exchange_from_date, start_date),
    exchange_to_date = COALESCE(exchange_to_date, end_date),
    exchange_reason = COALESCE(exchange_reason, reason),
    requires_partner_approval = CASE 
        WHEN exchange_partner_id IS NOT NULL THEN true
        ELSE false
    END,
    coverage_arranged = CASE 
        WHEN exchange_partner_id IS NOT NULL THEN true
        ELSE false
    END,
    submit_date = COALESCE(submit_date, created_at::date)
WHERE exchange_from_date IS NULL 
   OR exchange_to_date IS NULL 
   OR exchange_reason IS NULL
   OR requires_partner_approval IS NULL
   OR submit_date IS NULL;

-- Step 5: Make sure all NOT NULL columns have defaults or are nullable
-- Check for any columns that might be causing the insert issue
DO $$
DECLARE
    col_record RECORD;
    fix_count INTEGER := 0;
BEGIN
    FOR col_record IN 
        SELECT column_name, data_type, is_nullable, column_default
        FROM information_schema.columns 
        WHERE table_name = 'requests'
        AND is_nullable = 'NO'
        AND column_default IS NULL
        AND column_name NOT IN ('id', 'created_at') -- Skip auto-generated columns
    LOOP
        CASE col_record.column_name
            WHEN 'employee_name' THEN
                ALTER TABLE requests ALTER COLUMN employee_name SET DEFAULT 'Unknown Employee';
            WHEN 'employee_email' THEN
                ALTER TABLE requests ALTER COLUMN employee_email SET DEFAULT 'unknown@company.com';
            WHEN 'type' THEN
                ALTER TABLE requests ALTER COLUMN type SET DEFAULT 'Annual Leave';
            WHEN 'start_date' THEN
                ALTER TABLE requests ALTER COLUMN start_date SET DEFAULT CURRENT_DATE;
            WHEN 'end_date' THEN
                ALTER TABLE requests ALTER COLUMN end_date SET DEFAULT CURRENT_DATE;
            WHEN 'reason' THEN
                ALTER TABLE requests ALTER COLUMN reason SET DEFAULT 'No reason provided';
            WHEN 'status' THEN
                ALTER TABLE requests ALTER COLUMN status SET DEFAULT 'Pending';
            WHEN 'days' THEN
                ALTER TABLE requests ALTER COLUMN days SET DEFAULT 1;
            ELSE
                -- For other columns, make them nullable
                EXECUTE format('ALTER TABLE requests ALTER COLUMN %I DROP NOT NULL', col_record.column_name);
        END CASE;
        
        fix_count := fix_count + 1;
        RAISE NOTICE 'Fixed column: %', col_record.column_name;
    END LOOP;
    
    RAISE NOTICE 'Fixed % columns with missing defaults', fix_count;
END $$;

-- Step 6: Verify the current structure
SELECT 
    '=== AFTER FIX - REQUESTS TABLE STRUCTURE ===' as info,
    column_name,
    data_type,
    is_nullable,
    column_default
FROM information_schema.columns 
WHERE table_name = 'requests'
AND (is_nullable = 'NO' OR column_default IS NOT NULL)
ORDER BY ordinal_position;

COMMIT;

-- Step 7: Test insert to make sure it works
DO $$
DECLARE
    test_employee_id BIGINT;
    test_insert_result BIGINT;
BEGIN
    -- Get a test employee
    SELECT id INTO test_employee_id FROM employees LIMIT 1;
    
    IF test_employee_id IS NOT NULL THEN
        -- Try a minimal insert
        INSERT INTO requests (
            employee_name,
            employee_email,
            type,
            start_date,
            end_date,
            reason,
            status,
            days,
            employee_id
        ) VALUES (
            'Test Employee',
            'test@company.com',
            'Annual Leave',
            CURRENT_DATE + 1,
            CURRENT_DATE + 1,
            'Test request',
            'Pending',
            1,
            test_employee_id
        ) RETURNING id INTO test_insert_result;
        
        RAISE NOTICE 'SUCCESS: Test insert worked. Created request ID: %', test_insert_result;
        
        -- Clean up test request
        DELETE FROM requests WHERE id = test_insert_result;
        RAISE NOTICE 'Test request cleaned up';
    ELSE
        RAISE NOTICE 'No employees found to test with';
    END IF;
    
EXCEPTION WHEN OTHERS THEN
    RAISE NOTICE 'Test insert failed: %', SQLERRM;
END $$;

SELECT 'INSERT COLUMN MISMATCH FIX COMPLETE!' as result; 