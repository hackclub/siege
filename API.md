# Siege API Documentation

This document describes the available API endpoints for the Siege application.

## Authentication

Most API endpoints require authentication. Authentication is handled via session cookies. For API access, users must be logged in through the web interface.

## Endpoints

### Project Hours API

#### GET /api/project_hours/:id

Retrieves the total hours spent on a project for the current week based on Hackatime data.

**Parameters:**
- `id` (path): Project ID

**Response:**
```json
{
  "hours": 42.5,
  "week_start": "2024-01-01",
  "week_end": "2024-01-07"
}
```

**Error Responses:**
- `404 Not Found`: Project not found
- `403 Forbidden`: Insufficient permissions

### Public Beta API

The Public Beta API provides read-only access to project and user data for external integrations.

#### GET /api/public-beta

Returns a list of available endpoints.

**Response:**
```json
{
  "endpoints": {
    "projects": "/api/public-beta/projects",
    "project": "/api/public-beta/project/:id",
    "user": "/api/public-beta/user/:id_or_slack_id",
    "shop": "/api/public-beta/shop",
    "leaderboard": "/api/public-beta/leaderboard"
  }
}
```

#### GET /api/public-beta/projects

Retrieves a list of all visible projects.

**Response:**
```json
{
  "projects": [
    {
      "id": 123,
      "name": "My Awesome Project",
      "description": "A description of the project",
      "status": "finished",
      "repo_url": "https://github.com/user/project",
      "demo_url": "https://project.demo.com",
      "created_at": "2024-01-01T00:00:00.000Z",
      "updated_at": "2024-01-07T00:00:00.000Z",
      "user": {
        "id": 456,
        "name": "John Doe",
        "display_name": "johndoe"
      },
      "week_badge_text": "Week 1",
      "coin_value": 100,
      "is_update": false
    }
  ]
}
```

#### GET /api/public-beta/project/:id

Retrieves information about a specific project.

**Parameters:**
- `id` (path): Project ID

**Response:**
```json
{
  "id": 123,
  "name": "My Awesome Project",
  "description": "A description of the project",
  "status": "finished",
  "repo_url": "https://github.com/user/project",
  "demo_url": "https://project.demo.com",
  "created_at": "2024-01-01T00:00:00.000Z",
  "updated_at": "2024-01-07T00:00:00.000Z",
  "user": {
    "id": 456,
    "name": "John Doe",
    "display_name": "johndoe"
  },
  "week_badge_text": "Week 1",
  "coin_value": 100,
  "is_update": false
}
```

**Error Responses:**
- `404 Not Found`: Project not found or not visible

#### GET /api/public-beta/user/:id_or_slack_id

Retrieves information about a specific user and their visible projects.

**Parameters:**
- `id_or_slack_id` (path): User ID or Slack ID

**Response:**
```json
{
  "id": 456,
  "slack_id": "U1234567890",
  "name": "John Doe",
  "display_name": "johndoe",
  "coins": 150,
  "rank": "Apprentice",
  "status": "active",
  "created_at": "2024-01-01T00:00:00.000Z",
  "projects": [
    {
      "id": 123,
      "name": "My Project",
      "status": "finished",
      "created_at": "2024-01-01T00:00:00.000Z",
      "week_badge_text": "Week 1"
    }
  ]
}
```

**Error Responses:**
- `404 Not Found`: User not found

#### GET /api/public-beta/shop

Retrieves available cosmetics and physical items for purchase.

**Response:**
```json
{
  "cosmetics": [
    {
      "id": 1,
      "name": "Cool Hat",
      "description": "A very cool hat",
      "type": "hat",
      "cost": 50
    }
  ],
  "physical_items": [
    {
      "id": 2,
      "name": "Sticker Pack",
      "description": "Awesome stickers",
      "cost": 25,
      "digital": false
    }
  ]
}
```

#### GET /api/public-beta/leaderboard

Retrieves the top 50 users by coin count (excluding banned users).

**Response:**
```json
{
  "leaderboard": [
    {
      "id": 456,
      "slack_id": "U1234567890",
      "name": "John Doe",
      "display_name": "johndoe",
      "coins": 150,
      "rank": "Apprentice"
    }
  ]
}
```

### Submit API

The Submit API handles project submission authorization through an external service.

#### POST /api/submit/authorize

Creates an authorization request for project submission.

**Authentication:** Required

**Response:**
Returns the authorization response from the external submit service.

**Error Responses:**
- `401 Unauthorized`: User not authenticated
- `400 Bad Request`: Failed to create authorization request
- `500 Internal Server Error`: Server error

#### GET /api/submit/status/:auth_id

Checks the status of an authorization request.

**Parameters:**
- `auth_id` (path): Authorization ID

**Authentication:** Required

**Response:**
Returns the status response from the external submit service.

**Error Responses:**
- `401 Unauthorized`: User not authenticated
- `400 Bad Request`: Invalid auth_id or failed to check status
- `500 Internal Server Error`: Server error

## Error Handling

All API endpoints return appropriate HTTP status codes and JSON error responses:

```json
{
  "error": "Error message description"
}
```

## Rate Limiting

API endpoints may be subject to rate limiting. If you encounter rate limiting, please wait before making additional requests.

## Support

For API support or questions, please contact the development team.</content>
</xai:function_call">API.md