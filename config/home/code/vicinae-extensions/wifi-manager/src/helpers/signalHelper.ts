export const getSignalIcon = (signal?: number): string => {
  if (signal === undefined || signal === null) return "●○○○";
  if (signal >= 75) return "●●●●";
  if (signal >= 50) return "●●●○";
  if (signal >= 25) return "●●○○";
  return "●○○○";
};

