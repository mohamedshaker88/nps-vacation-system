-- Add requires_partner_approval field to requests table
ALTER TABLE requests 
ADD COLUMN IF NOT EXISTS requires_partner_approval BOOLEAN DEFAULT false;

-- Update existing requests to require partner approval
UPDATE requests 
SET requires_partner_approval = true 
WHERE exchange_partner_id IS NOT NULL;

-- Create index for better performance
CREATE INDEX IF NOT EXISTS idx_requests_partner_approval ON requests(requires_partner_approval, exchange_partner_id); 