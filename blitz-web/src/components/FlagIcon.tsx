/** Real SVG country flags via the `flag-icons` package — emoji flags render as
 * plain letter pairs on some platforms (e.g. Windows/Chromium), so we use actual
 * flag artwork instead of relying on OS emoji font support. */
export function FlagIcon({ code, className = '' }: { code: string; className?: string }) {
  if (!code) return null;
  return <span className={`fi fi-${code.toLowerCase()} rounded-[3px] align-middle shadow-sm ${className}`} />;
}
