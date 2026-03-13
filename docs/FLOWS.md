# MiniAppsSDK Flow Charts

## 1) High-Level End-to-End Flow

```mermaid
flowchart TD
    A[Host iOS App Starts] --> B[Initialize MiniAppsSDK]
    B --> C[Fetch Mini Apps List]
    C --> D[Render Banner View]
    C --> E[Background Download/Update Mini Apps]
    D --> F[User Taps Banner]
    F --> G[Request Required Permissions]
    G -->|Granted| H[Open Mini App in WKWebView]
    G -->|Denied| I[Abort Launch]
    H --> J[User Closes Mini App]
    J --> K[Report Metrics and Return to Host App]
```

## 2) Fetch + Cache + Refresh Flow

```mermaid
flowchart TD
    A[fetchMiniApps called] --> B{SDK initialized?}
    B -->|No| C[Return error]
    B -->|Yes| D{Cached mini apps available?}
    D -->|Yes| E[Return cached list immediately]
    E --> F[Refresh from API in background]
    D -->|No| G[Fetch list from API]
    G --> H{API success?}
    H -->|No| I[Return error]
    H -->|Yes| J[Cache response]
    J --> K[Return sorted list]
    K --> L[Start background download for each app]
```

## 3) Download and Version Decision Flow

```mermaid
flowchart TD
    A[Process mini app] --> B[Read stored version]
    B --> C[Check ZIP exists]
    C --> D{ZIP missing OR version outdated?}
    D -->|No| E[Skip download]
    D -->|Yes| F{Already downloading?}
    F -->|Yes| G[Skip duplicate]
    F -->|No| H[Request download token]
    H --> I{Token success?}
    I -->|No| J[Log failure]
    I -->|Yes| K[Resolve download URL]
    K --> L[Download ZIP]
    L --> M[Checksum verify]
    M --> N[Extract bundle]
    N --> O[Persist version and mark success]
```

## 4) Mini App Launch Flow

```mermaid
flowchart TD
    A[Banner tapped] --> B[Request permissions]
    B --> C{Permissions granted?}
    C -->|No| D[Log denied and stop]
    C -->|Yes| E[Find top view controller]
    E --> F[Create MiniAppViewController]
    F --> G[Present full-screen navigation controller]
    G --> H[Load local index.html in WKWebView]
    H --> I[Report AppLaunched metric]
    I --> J[User taps back]
    J --> K[Dismiss and report AppClosed metric]
```

## 5) Metrics Reporting Flow

```mermaid
flowchart TD
    A[SDK event occurs] --> B[Build metrics payload]
    B --> C[Include appId, version, device, OS, superAppVersion]
    C --> D[POST to metrics endpoint]
    D --> E{Request success?}
    E -->|Yes| F[Log success]
    E -->|No| G[Log failure without blocking UX]
```
