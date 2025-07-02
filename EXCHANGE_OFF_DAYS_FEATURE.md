# Exchange Off Days Feature

## Overview
The Exchange Off Days feature allows employees to request to exchange their scheduled off days with other days. This is useful when employees need to adjust their work schedule for personal reasons while maintaining proper coverage.

## Features

### For Employees
- Submit exchange requests through the employee portal
- Specify the original off day date and the new desired off day date
- Provide a reason for the exchange request
- Track the status of exchange requests
- View exchange information in the requests table

### For Administrators
- Review and approve/reject exchange requests
- View exchange details in the admin dashboard
- Track all exchange requests in the system
- Manage exchange request workflow

## How It Works

1. **Employee submits exchange request:**
   - Selects "Exchange Off Days" as the leave type
   - Specifies the original off day date (exchange from date)
   - Specifies the new desired off day date (exchange to date)
   - Provides a reason for the exchange
   - Submits the request

2. **Administrator reviews request:**
   - Views the exchange request in the admin dashboard
   - Sees the original and new dates
   - Reviews the reason provided
   - Approves or rejects the request

3. **Request processing:**
   - Approved requests are processed
   - Rejected requests are returned to the employee
   - All requests are tracked in the system

## Database Schema

The following fields have been added to the `requests` table:

- `exchange_from_date` (DATE): The original off day date
- `exchange_to_date` (DATE): The new desired off day date
- `exchange_reason` (TEXT): The reason for the exchange request

## Implementation Details

### Frontend Changes
- Added "Exchange Off Days" to the leave types list
- Updated request forms to include exchange-specific fields
- Modified request tables to display exchange information
- Added validation for exchange requests

### Backend Changes
- Updated database schema to support exchange fields
- Added indexes for better query performance
- Updated API endpoints to handle exchange data

## Usage Guidelines

### For Employees
- Exchange requests should be submitted at least 2 weeks in advance
- Provide clear and valid reasons for the exchange
- Ensure the new date doesn't conflict with team coverage requirements
- Exchange requests are subject to approval

### For Administrators
- Review exchange requests carefully
- Consider team coverage and operational needs
- Ensure the exchange doesn't create scheduling conflicts
- Communicate decisions promptly to employees

## Migration

To add this feature to an existing database, run the migration script:

```sql
-- Run migration-add-exchange-fields.sql in your Supabase SQL Editor
```

This will:
- Add the exchange fields to the requests table
- Create necessary indexes
- Add documentation comments

## Policy Integration

The exchange off days feature is integrated with the dynamic policy system. The leave type is defined in the policies table and can be customized by administrators.

## Future Enhancements

Potential future improvements:
- Bulk exchange request processing
- Automated conflict detection
- Integration with calendar systems
- Advanced approval workflows
- Exchange request templates 