# GlampingStations - API Integration

This iOS app has been updated to use a remote API instead of Core Data for fetching station data.

## Changes Made

### 1. Removed Core Data Dependencies
- Removed Core Data imports and setup from `AppDelegate.swift`
- Removed Core Data model files and persistent container
- Updated `StationsController.swift` to use API calls instead of local JSON file

### 2. API Integration
- Created `APIConfig.swift` for centralized API configuration
- Updated `StationsController.swift` with new API methods:
  - `fetchStations()` - Fetches stations from API
  - `updateStationComment()` - Updates station comments via API
  - `commentForStation()` - Retrieves station comments from API

### 3. Updated UI Components
- Modified `StationDetailsViewController.swift` to use asynchronous API calls
- Updated `StationDetailsTableViewCell.swift` to handle API responses with proper error handling

## Configuration

### API Setup
1. Open `APIConfig.swift`
2. Replace the placeholder values with your actual API configuration:

```swift
static let baseURL = "https://your-api-domain.com" // Your API base URL
static let apiKey = "your-api-key-here" // Your API key (if required)
```

### API Endpoints Expected
The app expects the following API endpoints:

#### GET /stations
Returns an array of station objects in JSON format:
```json
[
  {
    "id": "station_id",
    "latitude": 37.7749,
    "longitude": -122.4194,
    "name": "Station Name",
    "rating": "5 stars"
  }
]
```

#### GET /stations/{stationId}/comment
Returns the comment for a specific station:
```json
{
  "comment": "User's comment text"
}
```

#### PUT /stations/{stationId}/comment
Updates the comment for a specific station. Request body:
```json
{
  "comment": "New comment text"
}
```

## Error Handling
- Network errors are handled gracefully with user-friendly alerts
- Failed API calls show appropriate error messages
- The app continues to function even if the API is temporarily unavailable

## Testing
To test the API integration:
1. Update the API configuration in `APIConfig.swift`
2. Build and run the app
3. The app will attempt to fetch stations from your API
4. Test comment functionality by adding comments to stations

## Fallback Strategy
If you need to maintain offline functionality, consider:
1. Implementing local caching of API responses
2. Adding a fallback to the original JSON file if API is unavailable
3. Using Core Data for local storage of API responses

## Notes
- All API calls are asynchronous and run on background threads
- UI updates are properly dispatched to the main thread
- The app maintains the same user experience while using remote data 