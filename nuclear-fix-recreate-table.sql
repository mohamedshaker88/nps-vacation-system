-- NUCLEAR FIX - Recreate requests table with minimal schema
-- WARNING: This will delete all existing requests data
-- Only run this if you're okay with losing existing data

BEGIN;

-- Step 1: Backup existing data (if any)
CREATE TABLE IF NOT EXISTS requests_backup AS 
SELECT * FROM requests;

-- Step 2: Drop the existing table and all its dependencies
DROP TABLE IF EXISTS requests CASCADE;

-- Step 3: Create a minimal, clean requests table
CREATE TABLE requests (
    id BIGSERIAL PRIMARY KEY,
    employee_name VARCHAR(255) DEFAULT '',
    employee_email VARCHAR(255) DEFAULT '',
    type VARCHAR(100) DEFAULT 'Annual Leave',
    start_date DATE DEFAULT CURRENT_DATE,
    end_date DATE DEFAULT CURRENT_DATE,
    days INTEGER DEFAULT 1,
    reason TEXT DEFAULT '',
    status VARCHAR(50) DEFAULT 'Pending',
    submit_date DATE DEFAULT CURRENT_DATE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Step 4: Add exchange columns with proper defaults
ALTER TABLE requests 
ADD COLUMN employee_id BIGINT,
ADD COLUMN exchange_partner_id BIGINT,
ADD COLUMN exchange_partner_approved BOOLEAN DEFAULT NULL,
ADD COLUMN exchange_partner_approved_at TIMESTAMP WITH TIME ZONE DEFAULT NULL,
ADD COLUMN exchange_partner_notes TEXT DEFAULT NULL,
ADD COLUMN exchange_from_date DATE DEFAULT NULL,
ADD COLUMN exchange_to_date DATE DEFAULT NULL,
ADD COLUMN exchange_reason TEXT DEFAULT NULL,
ADD COLUMN partner_desired_off_date DATE DEFAULT NULL,
ADD COLUMN requires_partner_approval BOOLEAN DEFAULT false,
ADD COLUMN coverage_arranged BOOLEAN DEFAULT false,
ADD COLUMN coverage_by TEXT DEFAULT NULL,
ADD COLUMN medical_certificate BOOLEAN DEFAULT false,
ADD COLUMN emergency_contact TEXT DEFAULT NULL,
ADD COLUMN additional_notes TEXT DEFAULT NULL;

-- Step 5: Add foreign key constraints
ALTER TABLE requests 
ADD CONSTRAINT requests_employee_id_fkey 
FOREIGN KEY (employee_id) REFERENCES employees(id);

ALTER TABLE requests 
ADD CONSTRAINT requests_exchange_partner_id_fkey 
FOREIGN KEY (exchange_partner_id) REFERENCES employees(id);

-- Step 6: Create indexes
CREATE INDEX idx_requests_employee_email ON requests(employee_email);
CREATE INDEX idx_requests_status ON requests(status);
CREATE INDEX idx_requests_created_at ON requests(created_at DESC);
CREATE INDEX idx_requests_exchange_partner ON requests(exchange_partner_id);

-- Step 7: Test the minimal insert
DO $$
DECLARE
    test_result BIGINT;
BEGIN
    -- Test basic insert
    INSERT INTO requests (employee_name, employee_email, type, reason)
    VALUES ('Test User', 'test@example.com', 'Annual Leave', 'Test request')
    RETURNING id INTO test_result;
    
    RAISE NOTICE 'SUCCESS: Basic insert worked! Request ID: %', test_result;
    
    -- Clean up test
    DELETE FROM requests WHERE id = test_result;
    
    -- Test exchange insert
    INSERT INTO requests (
        employee_name, 
        employee_email, 
        type, 
        reason,
        exchange_partner_id,
        exchange_reason
    ) VALUES (
        'Exchange User', 
        'exchange@example.com', 
        'Exchange Off Days', 
        'Test exchange',
        1,
        'Test exchange reason'
    ) RETURNING id INTO test_result;
    
    RAISE NOTICE 'SUCCESS: Exchange insert worked! Request ID: %', test_result;
    
    -- Clean up test
    DELETE FROM requests WHERE id = test_result;
    
EXCEPTION WHEN OTHERS THEN
    RAISE NOTICE 'Insert still failing: %', SQLERRM;
    RAISE NOTICE 'Error code: %', SQLSTATE;
END $$;

-- Step 8: Show the new table structure
SELECT 
    '=== NEW REQUESTS TABLE STRUCTURE ===' as info,
    column_name,
    data_type,
    is_nullable,
    column_default
FROM information_schema.columns 
WHERE table_name = 'requests'
ORDER BY ordinal_position;

COMMIT;

SELECT 'NUCLEAR FIX COMPLETE - Table recreated with minimal schema!' as result; 