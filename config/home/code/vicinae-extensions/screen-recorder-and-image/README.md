# Screen Recorder and Image

A comprehensive Vicinae extension for capturing screenshots and recording screen content with audio support.

## Features

### Screenshot Command
- **Multiple capture modes**: Full screen, window selection, or custom region
- **Flexible saving**: Choose custom filename and save location
- **Clipboard integration**: Automatically copy screenshots to clipboard
- **Cross-platform support**: Works on macOS and Linux

### Screen Recording Command
- **Video recording**: Capture full screen, specific windows, or selected regions
- **Audio options**: Record system audio, microphone, or both
- **Custom output**: Choose filename and save location
- **Real-time controls**: Start and stop recording with visual feedback

## Commands

### `screenshot`
**Title**: Take Screenshot  
**Description**: Capture screenshots with region selection and clipboard options

**Options**:
- **Capture Type**: Full Screen, Window, or Selection
- **Filename**: Custom filename (auto-generated if empty)
- **Save Location**: Choose where to save the screenshot
- **Copy to Clipboard**: Automatically copy to clipboard (enabled by default)

### `screen-record`
**Title**: Screen Record  
**Description**: Record screen with audio options and path selection

**Options**:
- **Recording Area**: Full Screen, Window, or Selection
- **Filename**: Custom filename (auto-generated if empty)
- **Save Location**: Choose where to save the recording
- **Record Audio**: Include system audio in recording (enabled by default)
- **Record Microphone**: Include microphone input (requires system audio)

## Platform Support

### macOS
- **Screenshots**: Uses `screencapture` command
- **Screen Recording**: Uses `screencapture` with video mode
- **Clipboard**: Uses AppleScript for image clipboard operations

### Linux
- **Screenshots**: Uses `gnome-screenshot` command
- **Screen Recording**: Uses `ffmpeg` with X11 capture
- **Clipboard**: Uses `xclip` for image clipboard operations

## Installation

1. Install dependencies:
   ```bash
   npm install
   ```

2. Build the extension:
   ```bash
   npm run build
   ```

3. The extension will be built to your Vicinae extensions directory

## Development

### Scripts
- `npm run build`: Build the extension for production
- `npm run dev`: Start development mode with hot reload

### Dependencies
- `@vicinae/api`: Vicinae extension API
- React components for UI
- Node.js built-in modules for system operations

## Technical Details

### File Formats
- **Screenshots**: PNG format (high quality, lossless)
- **Screen Recordings**: MOV format (macOS) / various formats (Linux)

### Audio Recording
- **macOS**: System audio and microphone through screencapture
- **Linux**: Pulse audio integration through ffmpeg

### Error Handling
- Comprehensive error messages for failed operations
- Platform detection and fallback options
- Graceful handling of missing dependencies

## Troubleshooting

### Common Issues

1. **"Unsupported platform" error**
   - Ensure you're running on macOS or Linux
   - Check that required system tools are installed

2. **Recording fails to start**
   - Verify system permissions for screen recording
   - Check that audio devices are available if audio recording is enabled

3. **Screenshot not saving**
   - Ensure the target directory exists and is writable
   - Check available disk space

### Required System Tools

**macOS**:
- `screencapture` (built-in)
- `osascript` (built-in)

**Linux**:
- `gnome-screenshot` or equivalent
- `ffmpeg` (for screen recording)
- `xclip` (for clipboard operations)

## License

MIT License - see package.json for details

## Contributing

Feel free to submit issues and enhancement requests. Make sure to follow the existing code style and add appropriate tests for new features.
