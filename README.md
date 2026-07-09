# Sparkles 🫧

Sparkles is a modern, offline-first multi-tenant laundry management SaaS platform. It provides a robust backend dashboard for office administrators and a seamless offline-capable Flutter mobile application for staff and drivers on the go.

## Architecture Overview

This repository contains both the backend server and the mobile frontend application:

- **`laundry_backend/`**: A Django/Django Rest Framework (DRF) application that powers the core business logic, tenant isolation, SaaS billing, and synchronization APIs.
- **`laundry_mobile/`**: A Flutter application designed with an offline-first architecture using SQLite, Riverpod, and Dio.

## Features

### 🚀 Production-Ready Backend (Django)
- **Multi-Tenancy**: Data is strictly isolated by `LaundryOffice`, ensuring privacy and security across different laundry vendors.
- **Offline-First Delta Sync**: A highly optimized `/api/sync/` endpoint allows the mobile app to sync thousands of records (Orders, Categories, Pricing) instantly using timestamp-based delta payloads and tombstones (soft deletes).
- **Audit Trails**: Built-in `ActionLog` system automatically tracks who created or updated critical operational data.
- **SaaS Tier Enforcement**: Custom DRF middleware (`TierLimitPermission`) enforces subscription limits (e.g., maximum staff accounts for the Free tier).
- **Integrations Setup**: Pre-configured scaffolds for **Paystack** webhooks (subscription billing) and **WhatsApp** notifications (customer alerts).
- **Security**: Global pagination and rate-limiting to prevent abuse.

### 📱 Offline-First Mobile App (Flutter)
- **Riverpod State Management**: Reactive UI updates powered by Riverpod.
- **SQLite Local Database**: Full local schemas (`orders`, `service_types`, `categories`, `order_items`, `item_pricing`, `order_statuses`) to allow 100% offline functionality.
- **Background Sync Engine**: Automatically pulls delta updates, processes massive JSON payloads via SQLite `Batch` transactions, and gracefully handles physical deletions based on server tombstones.
- **Data Models**: Strongly-typed Dart models equipped to handle sync metadata (`updated_at`, `is_deleted`).

## Getting Started (Backend)

### Prerequisites
- Python 3.10+
- Django 4.2+

### Local Setup
1. Navigate to the backend directory:
   ```bash
   cd laundry_backend
   ```
2. Install dependencies:
   ```bash
   pip install -r requirements.txt
   ```
3. Run migrations:
   ```bash
   python manage.py migrate
   ```
4. Start the server:
   ```bash
   python manage.py runserver
   ```

### Deployment (Vercel)
The backend is fully configured for deployment on Vercel. 
Ensure you set the Vercel **Build Command** to:
```bash
bash build_files.sh
```
This ensures that `WhiteNoise` can properly collect and serve the Django static files (admin panel, bootstrap CSS) in production.

## Getting Started (Mobile)

### Prerequisites
- Flutter SDK (latest stable)
- Android Studio / Xcode for emulators

### Local Setup
1. Navigate to the mobile directory:
   ```bash
   cd laundry_mobile
   ```
2. Install dependencies:
   ```bash
   flutter pub get
   ```
3. Run the app:
   ```bash
   flutter run
   ```

*Note: Ensure your Android emulator or iOS simulator has access to the local backend server (e.g., `10.0.2.2` for Android instead of `localhost`). This is automatically configured in `api_service.dart`.*

## External API Keys
To fully utilize the integrations, add the following environment variables to your backend:
- `PAYSTACK_SECRET_KEY`: For SaaS billing and webhook verification.
- `WHATSAPP_API_URL` / `WHATSAPP_API_KEY`: For triggering customer notifications.
