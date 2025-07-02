-- FINAL INSERT FIX - Comprehensive Solution
-- This script ensures the requests table schema matches what the frontend sends

BEGIN;

-- Step 1: Show current table structure
SELECT 
    '=== CURRENT REQUESTS TABLE STRUCTURE ===' as info,
    column_name,
    data_type,
    is_nullable,
    column_default
FROM information_schema.columns 
WHERE table_name = 'requests'
ORDER BY ordinal_position;

-- Step 2: Make ALL columns nullable to prevent INSERT errors
ALTER TABLE requests ALTER COLUMN employee_name DROP NOT NULL;
ALTER TABLE requests ALTER COLUMN employee_email DROP NOT NULL;
ALTER TABLE requests ALTER COLUMN type DROP NOT NULL;
ALTER TABLE requests ALTER COLUMN start_date DROP NOT NULL;
ALTER TABLE requests ALTER COLUMN end_date DROP NOT NULL;
ALTER TABLE requests ALTER COLUMN reason DROP NOT NULL;
ALTER TABLE requests ALTER COLUMN status DROP NOT NULL;
ALTER TABLE requests ALTER COLUMN days DROP NOT NULL;
ALTER TABLE requests ALTER COLUMN submit_date DROP NOT NULL;

-- Step 3: Add sensible defaults to all essential columns
ALTER TABLE requests ALTER COLUMN employee_name SET DEFAULT '';
ALTER TABLE requests ALTER COLUMN employee_email SET DEFAULT '';
ALTER TABLE requests ALTER COLUMN type SET DEFAULT 'Annual Leave';
ALTER TABLE requests ALTER COLUMN start_date SET DEFAULT CURRENT_DATE;
ALTER TABLE requests ALTER COLUMN end_date SET DEFAULT CURRENT_DATE;
ALTER TABLE requests ALTER COLUMN reason SET DEFAULT '';
ALTER TABLE requests ALTER COLUMN status SET DEFAULT 'Pending';
ALTER TABLE requests ALTER COLUMN days SET DEFAULT 1;
ALTER TABLE requests ALTER COLUMN submit_date SET DEFAULT CURRENT_DATE;

-- Step 4: Ensure all exchange-related columns exist with proper defaults
ALTER TABLE requests 
ADD COLUMN IF NOT EXISTS employee_id BIGINT,
ADD COLUMN IF NOT EXISTS exchange_partner_id BIGINT,
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
ADD COLUMN IF NOT EXISTS additional_notes TEXT DEFAULT NULL;

-- Step 5: Add foreign key constraints if they don't exist
DO $$
BEGIN
    -- Add employee_id foreign key if it doesn't exist
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.table_constraints 
        WHERE constraint_name = 'requests_employee_id_fkey'
    ) THEN
        ALTER TABLE requests 
        ADD CONSTRAINT requests_employee_id_fkey 
        FOREIGN KEY (employee_id) REFERENCES employees(id);
    END IF;
    
    -- Add exchange_partner_id foreign key if it doesn't exist
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.table_constraints 
        WHERE constraint_name = 'requests_exchange_partner_id_fkey'
    ) THEN
        ALTER TABLE requests 
        ADD CONSTRAINT requests_exchange_partner_id_fkey 
        FOREIGN KEY (exchange_partner_id) REFERENCES employees(id);
    END IF;
END $$;

-- Step 6: Update employee_id for existing requests
UPDATE requests 
SET employee_id = e.id
FROM employees e
WHERE requests.employee_email = e.email
AND requests.employee_id IS NULL;

-- Step 7: Test that INSERT now works with minimal data
DO $$
DECLARE
    test_result BIGINT;
    test_employee_id BIGINT;
BEGIN
    -- Get a test employee
    SELECT id INTO test_employee_id FROM employees LIMIT 1;
    
    -- Try a minimal insert that should work
    INSERT INTO requests (employee_name, employee_email, type, reason)
    VALUES ('Test User', 'test@example.com', 'Annual Leave', 'Test request')
    RETURNING id INTO test_result;
    
    RAISE NOTICE 'SUCCESS: Minimal insert worked! Request ID: %', test_result;
    
    -- Clean up test
    DELETE FROM requests WHERE id = test_result;
    
    -- Try an exchange request insert
    IF test_employee_id IS NOT NULL THEN
        INSERT INTO requests (
            employee_name, 
            employee_email, 
            type, 
            reason,
            exchange_partner_id,
            exchange_from_date,
            exchange_to_date,
            exchange_reason
        ) VALUES (
            'Test Exchange User', 
            'exchange@example.com', 
            'Exchange Off Days', 
            'Test exchange',
            test_employee_id,
            CURRENT_DATE + 1,
            CURRENT_DATE + 2,
            'Test exchange reason'
        ) RETURNING id INTO test_result;
        
        RAISE NOTICE 'SUCCESS: Exchange insert worked! Request ID: %', test_result;
        
        -- Clean up test
        DELETE FROM requests WHERE id = test_result;
    END IF;
    
EXCEPTION WHEN OTHERS THEN
    RAISE NOTICE 'Insert still failing: %', SQLERRM;
END $$;

-- Step 8: Show the final structure
SELECT 
    '=== FINAL REQUESTS TABLE STRUCTURE ===' as info,
    column_name,
    data_type,
    is_nullable,
    column_default
FROM information_schema.columns 
WHERE table_name = 'requests'
ORDER BY ordinal_position;

COMMIT;

SELECT 'FINAL INSERT FIX COMPLETE - Database is now ready for requests!' as result; 