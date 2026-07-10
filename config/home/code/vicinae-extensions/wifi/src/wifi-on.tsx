import { showToast, Toast } from "@vicinae/api";
import { setWifi } from "./utils/nmcli";

export default async function WifiOn() {
  await setWifi(true);
  await showToast({ style: Toast.Style.Success, title: "WiFi enabled" });
}
