import { showToast, Toast } from "@vicinae/api";
import { setWifi } from "./utils/nmcli";

export default async function WifiOff() {
  await setWifi(false);
  await showToast({ style: Toast.Style.Success, title: "WiFi disabled" });
}
