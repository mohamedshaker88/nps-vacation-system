-- Create policies table for dynamic leave policy management
CREATE TABLE IF NOT EXISTS policies (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  content jsonb NOT NULL,
  updated_at timestamp with time zone DEFAULT now(),
  published boolean DEFAULT true
);

-- Only one policy is published at a time
CREATE UNIQUE INDEX IF NOT EXISTS idx_policies_published ON policies(published) WHERE published = true;

-- Insert a default policy
INSERT INTO policies (content, published) VALUES (
  '{
    "leaveTypes": [
      {"value": "Annual Leave", "label": "Annual Leave", "maxDays": 14, "paid": true, "description": "Paid vacation time"},
      {"value": "Sick Leave", "label": "Sick Leave", "maxDays": 1, "paid": true, "description": "Paid sick day (1 day maximum per request)"},
      {"value": "Emergency Leave", "label": "Emergency Leave", "maxDays": 3, "paid": false, "description": "Unpaid emergency leave"},
      {"value": "Personal Leave", "label": "Personal Day", "maxDays": 1, "paid": false, "description": "Unpaid personal day"},
      {"value": "Maternity Leave", "label": "Maternity Leave", "maxDays": 70, "paid": false, "description": "Unpaid maternity leave"},
      {"value": "Paternity Leave", "label": "Paternity Leave", "maxDays": 7, "paid": false, "description": "Unpaid paternity leave"},
      {"value": "Bereavement Leave", "label": "Bereavement Leave", "maxDays": 5, "paid": false, "description": "Unpaid bereavement leave"},
      {"value": "Religious Leave", "label": "Religious Leave", "maxDays": 2, "paid": false, "description": "Unpaid religious observance"},
      {"value": "Compensatory Time", "label": "Comp Time", "maxDays": 3, "paid": false, "description": "Unpaid compensation time"},
      {"value": "Exchange Off Days", "label": "Exchange Off Days", "maxDays": 7, "paid": false, "description": "Exchange scheduled off days with other days", "isExchange": true}
    ],
    "entitlements": {
      "annualLeave": 15,
      "sickLeave": 10
    },
    "guidelines": {
      "requestProcedures": [
        "Submit requests at least 2 weeks in advance for planned leave",
        "Emergency leave can be requested with 24-hour notice",
        "All requests must include coverage arrangements",
        "Medical certificates required for sick leave documentation",
        "Maximum 3 people can be on leave simultaneously",
        "Peak periods (holidays) require 4 weeks advance notice"
      ],
      "coverageRequirements": [
        "24/7 coverage must be maintained (5pm-1am daily)",
        "Minimum 8 staff members must be available",
        "Cross-training required for all team members",
        "Emergency contact list maintained",
        "Backup coverage person must confirm availability",
        "Weekend coverage requires special arrangement"
      ]
    }
  }'::jsonb,
  true
); 