/// <reference types="@vicinae/api">

/*
 * This file is auto-generated from the extension's manifest.
 * Do not modify manually. Instead, update the `package.json` file.
 */

type ExtensionPreferences = {
  
}

declare type Preferences = ExtensionPreferences

declare namespace Preferences {
  /** Command: Scan WiFi Networks */
	export type Scan = ExtensionPreferences & {
		
	}

	/** Command: Saved Networks */
	export type Saved = ExtensionPreferences & {
		
	}

	/** Command: Turn WiFi On */
	export type WifiOn = ExtensionPreferences & {
		
	}

	/** Command: Turn WiFi Off */
	export type WifiOff = ExtensionPreferences & {
		
	}
}

declare namespace Arguments {
  /** Command: Scan WiFi Networks */
	export type Scan = {
		
	}

	/** Command: Saved Networks */
	export type Saved = {
		
	}

	/** Command: Turn WiFi On */
	export type WifiOn = {
		
	}

	/** Command: Turn WiFi Off */
	export type WifiOff = {
		
	}
}