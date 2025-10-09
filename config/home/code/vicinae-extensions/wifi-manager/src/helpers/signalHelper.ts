import { NetworkIcons } from "./icons";

export const getSignalIcon = (signal?: number): string => {
  if (signal === undefined || signal === null) return "●○○○";
  if (signal >= 75) return "●●●●";
  if (signal >= 50) return "●●●○";
  if (signal >= 25) return "●●○○";
  return "●○○○";
};

export const getSignalIconVicinae = (signal?: number): string => {
  if (signal === undefined || signal === null) return NetworkIcons.Signal1;
  if (signal >= 75) return NetworkIcons.FullSignal;
  if (signal >= 50) return NetworkIcons.Signal3;
  if (signal >= 25) return NetworkIcons.Signal2;
  return NetworkIcons.Signal1;
};
