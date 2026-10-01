"""Apply foreground weather permission to the generated, gitignored iOS host.

Run after `flutter create --platforms=ios .` when setting up an iOS workspace.
The repository currently only versions its Android host.
"""
from pathlib import Path
import plistlib

path = Path(__file__).resolve().parents[1] / "ios" / "Runner" / "Info.plist"
with path.open("rb") as source:
    plist = plistlib.load(source)
plist["NSLocationWhenInUseUsageDescription"] = (
    "Docket uses your approximate location to show local weather when you open "
    "the weather glance."
)
with path.open("wb") as destination:
    plistlib.dump(plist, destination, sort_keys=False)
