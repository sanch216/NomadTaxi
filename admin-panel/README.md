# AIS Taxi - Admin Panel

React + TypeScript admin panel for managing the AIS Taxi platform.

## Features

- **Dashboard**: Real-time metrics and statistics
- **User Management**: View, ban/unban users
- **Ride Management**: Monitor and cancel rides
- **Transactions**: View all financial transactions
- **Promo Codes**: Create and manage promotional codes
- **Reviews**: Moderate user reviews
- **Support Tickets**: Handle customer support requests
- **Driver Applications**: Review and approve driver applications

## Tech Stack

- React 19
- TypeScript 6
- Vite 8
- React Router 7
- Axios

## Prerequisites

- Node.js 18+ and npm
- Backend server running on http://localhost:8080

## Installation

```bash
npm install
```

## Development

```bash
npm run dev
```

The app will be available at http://localhost:3000

## Build

```bash
npm run build
```

## Default Admin Credentials

- Phone: `+996700000000`
- Password: `admin123`

## API Endpoints

The admin panel connects to the following backend endpoints:

- `/auth/login` - Authentication
- `/api/admin/dashboard/metrics` - Dashboard metrics
- `/api/admin/users` - User management
- `/api/admin/rides` - Ride management
- `/api/admin/transactions` - Transaction management
- `/api/admin/promo-codes` - Promo code management
- `/api/admin/reviews` - Review moderation
- `/api/admin/tickets` - Support ticket management
- `/api/admin/driver-applications` - Driver application management

## Project Structure

```
admin-panel/
├── src/
│   ├── components/     # Reusable components
│   │   └── Layout.tsx  # Main layout with sidebar
│   ├── pages/          # Page components
│   │   ├── Dashboard.tsx
│   │   ├── Users.tsx
│   │   ├── Rides.tsx
│   │   ├── Transactions.tsx
│   │   ├── PromoCodes.tsx
│   │   ├── Reviews.tsx
│   │   ├── Tickets.tsx
│   │   └── DriverApplications.tsx
│   ├── services/       # API services
│   │   └── api.ts
│   ├── types/          # TypeScript types
│   │   └── index.ts
│   ├── App.tsx         # Main app component
│   └── main.tsx        # Entry point
├── index.html
├── vite.config.ts
├── tsconfig.json
└── package.json
```

## Notes

- JWT token is stored in localStorage
- All API requests include Authorization header with Bearer token
- Unauthorized requests (401) automatically redirect to login page
- API proxy configured in vite.config.ts for development
