# NPS Team Vacation Management System

A comprehensive vacation management system built with React, Vite, and Supabase for the NPS Team. Features both admin and employee portals with real-time data persistence.

## 🚀 Features

### Admin Dashboard
- **Dashboard Overview**: Real-time statistics and recent requests
- **Request Management**: Approve/reject leave requests
- **Employee Management**: View all registered employees and their leave balances
- **Policy Management**: Comprehensive leave policies and guidelines
- **Real-time Updates**: Live data synchronization with Supabase

### Employee Portal
- **User Authentication**: Secure login/registration with company email validation
- **Leave Request Submission**: Comprehensive request forms with validation
- **Request Tracking**: View all submitted requests and their status
- **Leave Balance**: Real-time tracking of annual and sick leave balances
- **Policy Information**: Access to company leave policies and guidelines

## 🛠️ Tech Stack

- **Frontend**: React 18, Vite, Tailwind CSS
- **Backend**: Supabase (PostgreSQL)
- **Authentication**: Supabase Auth
- **Icons**: Lucide React
- **Routing**: React Router DOM

## 📋 Prerequisites

- Node.js (v16 or higher)
- npm or yarn
- Supabase account

## 🔧 Setup Instructions

### 1. Clone and Install Dependencies

```bash
# Install dependencies
npm install
```

### 2. Set Up Supabase

1. **Create a Supabase Project**:
   - Go to [supabase.com](https://supabase.com)
   - Create a new project
   - Note your project URL and anon key

2. **Create Database Tables**:

Run these SQL commands in your Supabase SQL editor:

```sql
-- Create employees table
CREATE TABLE employees (
  id BIGSERIAL PRIMARY KEY,
  name VARCHAR(255) NOT NULL,
  email VARCHAR(255) UNIQUE NOT NULL,
  phone VARCHAR(50),
  password VARCHAR(255) NOT NULL,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Create requests table
CREATE TABLE requests (
  id BIGSERIAL PRIMARY KEY,
  employee_name VARCHAR(255) NOT NULL,
  employee_email VARCHAR(255) NOT NULL,
  type VARCHAR(100) NOT NULL,
  start_date DATE NOT NULL,
  end_date DATE NOT NULL,
  days INTEGER NOT NULL,
  reason TEXT,
  status VARCHAR(50) DEFAULT 'Pending',
  submit_date DATE NOT NULL,
  coverage_arranged BOOLEAN DEFAULT FALSE,
  coverage_by VARCHAR(255),
  emergency_contact VARCHAR(255),
  additional_notes TEXT,
  medical_certificate BOOLEAN DEFAULT FALSE,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Create indexes for better performance
CREATE INDEX idx_requests_employee_email ON requests(employee_email);
CREATE INDEX idx_requests_status ON requests(status);
CREATE INDEX idx_employees_email ON employees(email);
```

3. **Configure Environment Variables**:

Create a `.env` file in the root directory:

```env
VITE_SUPABASE_URL=your_supabase_project_url
VITE_SUPABASE_ANON_KEY=your_supabase_anon_key
```

### 3. Run the Application

```bash
# Development mode
npm run dev

# Build for production
npm run build

# Preview production build
npm run preview
```

## 🔐 Authentication

### Admin Access
- **URL**: `/admin`
- **Username**: `admin`
- **Password**: `NPSTEAM!`

### Employee Access
- **URL**: `/employee`
- **Registration**: Employees can register with their `@technetworkinc.com` email
- **Login**: Use registered email and password

## 📊 Leave Types & Policies

### Paid Leave
- **Annual Leave**: 15 days per year
- **Sick Leave**: 10 days per year (1 day max per request)

### Unpaid Leave
- Emergency Leave (3 days)
- Personal Leave (1 day)
- Maternity Leave (70 days)
- Paternity Leave (7 days)
- Bereavement Leave (5 days)
- Religious Leave (2 days)
- Compensatory Time (3 days)

## 🚀 Deployment

### Deploy to Vercel

1. **Install Vercel CLI**:
   ```bash
   npm install -g vercel
   ```

2. **Deploy**:
   ```bash
   vercel --prod
   ```

3. **Set Environment Variables** in Vercel dashboard:
   - `VITE_SUPABASE_URL`
   - `VITE_SUPABASE_ANON_KEY`

### Deploy to Netlify

1. **Build the project**:
   ```bash
   npm run build
   ```

2. **Deploy the `dist` folder** to Netlify

3. **Set Environment Variables** in Netlify dashboard

## 🔧 Configuration

### Customizing Leave Types

Edit the `leaveTypes` array in both `AdminDashboard.jsx` and `EmployeePortal.jsx`:

```javascript
const leaveTypes = [
  { value: 'Annual Leave', label: 'Annual Leave', maxDays: 14, paid: true },
  // Add more leave types here
];
```

### Customizing Company Email Domain

Update the `validateEmail` function in `EmployeePortal.jsx`:

```javascript
const validateEmail = (email) => {
  return email.toLowerCase().endsWith('@yourcompany.com');
};
```

## 📱 Features

### Real-time Data
- All data is stored in Supabase PostgreSQL database
- Real-time synchronization across all users
- Automatic data persistence

### Responsive Design
- Mobile-friendly interface
- Optimized for desktop and tablet use
- Modern UI with Tailwind CSS

### Security
- Email domain validation
- Secure password storage (should be hashed in production)
- Protected admin routes

## 🐛 Troubleshooting

### Common Issues

1. **Supabase Connection Error**:
   - Verify your environment variables
   - Check Supabase project status
   - Ensure database tables are created

2. **Build Errors**:
   - Clear node_modules and reinstall: `rm -rf node_modules && npm install`
   - Check Node.js version compatibility

3. **Authentication Issues**:
   - Verify email domain validation
   - Check Supabase authentication settings

## 📞 Support

For technical support or questions:
- Email: support@technetworkinc.com
- Documentation: [Project Wiki](link-to-wiki)

## 📄 License

This project is proprietary software for NPS Team use only.

---

**Built with ❤️ for the NPS Team** 