-- DIAGNOSTIC SCRIPT - Find the exact cause of INSERT error
-- Run this in Supabase SQL Editor to see what's wrong

-- Step 1: Show the exact table structure
SELECT 
    '=== REQUESTS TABLE STRUCTURE ===' as info,
    column_name,
    data_type,
    is_nullable,
    column_default,
    ordinal_position
FROM information_schema.columns 
WHERE table_name = 'requests'
ORDER BY ordinal_position;

-- Step 2: Count total columns
SELECT 
    'Total columns in requests table:' as info,
    COUNT(*) as column_count
FROM information_schema.columns 
WHERE table_name = 'requests';

-- Step 3: Show columns without defaults that are NOT NULL
SELECT 
    'Columns without defaults that are NOT NULL:' as info,
    column_name,
    data_type,
    is_nullable,
    column_default
FROM information_schema.columns 
WHERE table_name = 'requests'
AND is_nullable = 'NO'
AND column_default IS NULL
AND column_name NOT IN ('id', 'created_at')
ORDER BY ordinal_position;

-- Step 4: Try to see what happens with a minimal insert
DO $$
DECLARE
    test_result BIGINT;
    error_message TEXT;
BEGIN
    RAISE NOTICE 'Attempting minimal insert...';
    
    BEGIN
        INSERT INTO requests (employee_name, employee_email, type, reason)
        VALUES ('Test User', 'test@example.com', 'Annual Leave', 'Test')
        RETURNING id INTO test_result;
        
        RAISE NOTICE 'SUCCESS: Minimal insert worked! Request ID: %', test_result;
        
        -- Clean up test
        DELETE FROM requests WHERE id = test_result;
        
    EXCEPTION WHEN OTHERS THEN
        error_message := SQLERRM;
        RAISE NOTICE 'Insert failed with error: %', error_message;
        RAISE NOTICE 'Error code: %', SQLSTATE;
        
        -- Try to get more details about the error
        IF error_message LIKE '%target columns%' THEN
            RAISE NOTICE 'This is a column count mismatch error';
        END IF;
    END;
END $$;

-- Step 5: Show the actual INSERT statement that would be generated
SELECT 
    'Sample INSERT statement:' as info,
    'INSERT INTO requests (' || 
    string_agg(column_name, ', ' ORDER BY ordinal_position) || 
    ') VALUES (...)' as insert_statement
FROM information_schema.columns 
WHERE table_name = 'requests'
AND column_name NOT IN ('id', 'created_at');

-- Step 6: Check if there are any triggers that might be causing issues
SELECT 
    'Triggers on requests table:' as info,
    trigger_name,
    event_manipulation,
    action_statement
FROM information_schema.triggers 
WHERE event_object_table = 'requests';

-- Step 7: Show any constraints that might be problematic
SELECT 
    'Constraints on requests table:' as info,
    constraint_name,
    constraint_type,
    table_name
FROM information_schema.table_constraints 
WHERE table_name = 'requests'; 