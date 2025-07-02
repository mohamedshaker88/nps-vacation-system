// Script to update the policy with only Annual Leave, Sick Leave, and Exchange Off Days
import { createClient } from '@supabase/supabase-js';

const supabaseUrl = 'https://your-project.supabase.co';
const supabaseKey = 'your-anon-key';

const supabase = createClient(supabaseUrl, supabaseKey);

const updatedPolicy = {
  leaveTypes: [
    { value: 'Annual Leave', label: 'Annual Leave', maxDays: 14, paid: true, description: 'Paid vacation time' },
    { value: 'Sick Leave', label: 'Sick Leave', maxDays: 1, paid: true, description: 'Paid sick day (1 day maximum per request)' },
    { value: 'Exchange Off Days', label: 'Exchange Off Days', maxDays: 1, paid: false, description: 'Exchange scheduled off days with other days', isExchange: true }
  ],
  entitlements: { annualLeave: 15, sickLeave: 10 },
  guidelines: {
    requestProcedures: [
      "Submit requests at least 2 weeks in advance for planned leave",
      "Emergency leave can be requested with 24-hour notice",
      "All requests must include coverage arrangements"
    ],
    coverageRequirements: [
      "24/7 coverage must be maintained (5pm-1am daily)",
      "Minimum 8 staff members must be available",
      "Cross-training required for all team members"
    ]
  }
};

async function updatePolicy() {
  try {
    const { data, error } = await supabase
      .from('policies')
      .upsert({
        id: 1,
        content: updatedPolicy,
        is_active: true,
        updated_at: new Date().toISOString()
      });

    if (error) {
      console.error('Error updating policy:', error);
    } else {
      console.log('Policy updated successfully!');
    }
  } catch (error) {
    console.error('Error:', error);
  }
}

updatePolicy(); 