# BraggingRights

BraggingRights is a native macOS application designed to help you track your professional accomplishments by aggregating and analyzing your Slack history. It simplifies the process of creating "brag documents" for performance reviews, promotion cycles, or personal reflection.

> **Note:** This project is open source for inspection and personal use only. Please see the [License](#license) section below for strict usage restrictions.

## Features

*   **Slack Message Import:** Easily paste and parse Slack messages directly into the app.
*   **Smart Parsing:** Automatically detects duplicates and organizes messages by import session.
*   **Message Library:** A comprehensive view to manage your history. Search, filter by channel/author, and sort your accomplishments.
*   **Local Persistence:** All data is stored securely on your local machine. Nothing is sent to the cloud until you choose to generate a summary.
*   **LLM Integration:** Connects with large-context LLMs (like GPT-4 Turbo, Claude 3, Gemini 1.5) to summarize your year's work into a coherent narrative.
*   **Workflow Focused:** A guided 3-step process: Import → Manage → Generate.

## How It Works

1.  **Import:** Search for your messages in Slack (e.g., `from:@me`), copy the results, and paste them into BraggingRights. The app handles pagination and incremental updates.
2.  **Organize:** Review your imported messages in the Library. Remove irrelevant items and verify your timeline.
3.  **Generate:** Use the built-in LLM tools to transform your raw message history into a structured brag document.

## Privacy

Your data belongs to you. BraggingRights stores all imported messages locally on your device in `~/Library/Application Support/BraggingRights/`. 

## Building the Project

### Requirements
*   macOS 14.0+ (Sonoma) or later
*   Xcode 15.0+

### Steps
1.  Clone the repository:
    ```bash
    git clone https://github.com/yourusername/BraggingRights.git
    ```
2.  Open the project in Xcode:
    ```bash
    open BraggingRights/BraggingRights.xcodeproj
    ```
3.  Build and Run (Cmd+R).

## Distribution 
For now I don't have any plans for releasing pre-built versions of this app or an AppStore/TestFlight release, but that might change in the future if people ask for it

## License & Usage Restrictions

**Strictly Non-Commercial & No Derivative Works**

By accessing or using this software, you agree to the following terms:

1.  **Personal Use Only:** You are free to view the source code and build the application for your own personal use.
2.  **No Commercial Use:** You may NOT use this software, its source code, or any part of it for commercial purposes. This includes, but is not limited to, selling the software, using it to provide a paid service, or integrating it into a commercial product.
3.  **No Derivative Works:** You may NOT modify, remix, transform, or build upon the material without explict permission. You may not distribute modified versions of this software without explict permission.

This work is licensed under the **Creative Commons Attribution-NonCommercial-NoDerivatives 4.0 International License** (CC BY-NC-ND 4.0). To view a copy of this license, visit http://creativecommons.org/licenses/by-nc-nd/4.0/.

## Contributing

Issues and bug reports are welcome.
Send Patches?
