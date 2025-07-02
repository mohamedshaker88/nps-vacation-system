-- Debug Admin Approval Issues
-- Run this to identify and fix approval problems

-- 1. Check if all required functions exist
SELECT 'Checking Database Functions:' as info;

SELECT 
    routine_name,
    routine_type,
    CASE WHEN routine_name IS NOT NULL THEN '✅ EXISTS' ELSE '❌ MISSING' END as status
FROM information_schema.routines 
WHERE routine_name IN (
    'can_admin_approve_request',
    'approve_exchange_request', 
    'swap_work_schedules_bidirectional',
    'update_request_status_and_schedules_bidirectional',
    'get_or_create_work_schedule'
)
AND routine_schema = 'public'
ORDER BY routine_name;

-- 2. Check current exchange requests and their status
SELECT 'Current Exchange Requests:' as info;

SELECT 
    r.id,
    r.employee_name,
    r.status,
    r.exchange_partner_id,
    e.name as partner_name,
    r.exchange_partner_approved,
    r.exchange_partner_approved_at,
    r.exchange_from_date,
    r.exchange_to_date,
    CASE 
        WHEN r.exchange_partner_approved IS NULL THEN '⏳ Waiting for partner'
        WHEN r.exchange_partner_approved = true AND r.status = 'Partner Approved' THEN '✅ Ready for admin approval'
        WHEN r.exchange_partner_approved = false THEN '❌ Partner rejected'
        WHEN r.status = 'Approved' THEN '🎉 Fully approved'
        ELSE '❓ Unknown state: ' || r.status
    END as workflow_status
FROM requests r
LEFT JOIN employees e ON e.id = r.exchange_partner_id
WHERE r.type = 'Exchange Off Days'
ORDER BY r.created_at DESC;

-- 3. Test admin approval check for each request
SELECT 'Testing Admin Approval Function:' as info;

DO $$
DECLARE
    req_record RECORD;
    approval_result RECORD;
BEGIN
    FOR req_record IN 
        SELECT id, employee_name, status 
        FROM requests 
        WHERE type = 'Exchange Off Days' 
        ORDER BY created_at DESC 
        LIMIT 5
    LOOP
        BEGIN
            SELECT can_approve, reason INTO approval_result 
            FROM can_admin_approve_request(req_record.id);
            
            RAISE NOTICE 'Request %: % (%) - Can Approve: %, Reason: %', 
                req_record.id, 
                req_record.employee_name, 
                req_record.status,
                approval_result.can_approve, 
                approval_result.reason;
        EXCEPTION WHEN OTHERS THEN
            RAISE NOTICE 'ERROR testing request %: %', req_record.id, SQLERRM;
        END;
    END LOOP;
END $$;

-- 4. Check if triggers are properly set up
SELECT 'Checking Triggers:' as info;

SELECT 
    trigger_name,
    event_manipulation,
    event_object_table,
    action_statement,
    CASE WHEN trigger_name IS NOT NULL THEN '✅ ACTIVE' ELSE '❌ MISSING' END as status
FROM information_schema.triggers 
WHERE trigger_name LIKE '%schedule%' OR trigger_name LIKE '%approval%'
ORDER BY trigger_name;

-- 5. Simple function to update request status with better error handling
CREATE OR REPLACE FUNCTION admin_approve_request_safe(
    p_request_id BIGINT,
    p_new_status TEXT
) RETURNS JSONB AS $$
DECLARE
    request_row requests%ROWTYPE;
    approval_check RECORD;
    result JSONB;
BEGIN
    -- Get the request
    SELECT * INTO request_row FROM requests WHERE id = p_request_id;
    
    IF request_row.id IS NULL THEN
        RETURN jsonb_build_object(
            'success', false, 
            'error', 'Request not found',
            'request_id', p_request_id
        );
    END IF;
    
    -- Check if admin can approve (only for Approved status)
    IF p_new_status = 'Approved' THEN
        BEGIN
            SELECT can_approve, reason INTO approval_check 
            FROM can_admin_approve_request(p_request_id);
            
            IF NOT approval_check.can_approve THEN
                RETURN jsonb_build_object(
                    'success', false,
                    'error', 'Cannot approve: ' || approval_check.reason,
                    'request_id', p_request_id,
                    'current_status', request_row.status
                );
            END IF;
        EXCEPTION WHEN OTHERS THEN
            RETURN jsonb_build_object(
                'success', false,
                'error', 'Error checking approval permissions: ' || SQLERRM,
                'request_id', p_request_id
            );
        END;
    END IF;
    
    -- Update the request status
    BEGIN
        UPDATE requests 
        SET status = p_new_status
        WHERE id = p_request_id;
        
        RETURN jsonb_build_object(
            'success', true,
            'message', 'Request status updated successfully',
            'request_id', p_request_id,
            'old_status', request_row.status,
            'new_status', p_new_status
        );
    EXCEPTION WHEN OTHERS THEN
        RETURN jsonb_build_object(
            'success', false,
            'error', 'Error updating request: ' || SQLERRM,
            'request_id', p_request_id
        );
    END;
END;
$$ LANGUAGE plpgsql;

-- 6. Test the safe approval function
SELECT 'Testing Safe Approval Function:' as info;

DO $$
DECLARE
    test_request_id BIGINT;
    test_result JSONB;
BEGIN
    -- Get a Partner Approved request to test
    SELECT id INTO test_request_id 
    FROM requests 
    WHERE status = 'Partner Approved' 
    AND type = 'Exchange Off Days'
    LIMIT 1;
    
    IF test_request_id IS NOT NULL THEN
        SELECT admin_approve_request_safe(test_request_id, 'Approved') INTO test_result;
        RAISE NOTICE 'Test result for request %: %', test_request_id, test_result;
    ELSE
        RAISE NOTICE 'No Partner Approved requests found to test';
    END IF;
END $$;

COMMIT; 