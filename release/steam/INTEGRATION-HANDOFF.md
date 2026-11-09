# Steam integration handoff — future work, not present in this demo

No Steamworks application or App ID exists for this project yet. The standalone
build launches offline without the Steam client. Nothing has been uploaded or published.

## Local achievements to map after an App ID exists
The current company save stores these stable identifiers. They are awarded from
simulation state, persist once earned, and are disabled in sandbox.

| API identifier | Display name | Trigger |
| --- | --- | --- |
| FIRST_WATT | First watt | Earn $1,200 with a working campus |
| TRUSTED_PROVIDER | Trusted provider | Deliver two campaign customers |
| NEURAL_SCALE | Neural scale | Deliver four campaign customers |
| FEED_THE_AI | Feed the AI | Complete research |
| HUMAN_TOUCH | The human touch | Complete repair/service with technicians employed |
| TOWN_STEWARD | Town steward | Preserve three parks/landmarks |
| LIGHTS_ON | Keep the lights on | Finish an incident using backup power with no lost compute |
| LITTLEBROOK | Littlebrook's future | Complete the Littlebrook charter |
| SUNSPRAWL | Beat the heat | Complete the Sunsprawl charter |
| OLDBRIDGE | History and capacity | Complete the Oldbridge charter |

Future Steam implementation: configure these IDs and icons in Steamworks, initialize
the supported SDK/plugin, load user stats, enqueue awards, store them successfully,
and retry failures without blocking gameplay. Test offline earnings and reconnect.
Keep local saves usable if the Steam API is absent. Decide explicitly whether to
import achievements from existing standalone saves; do not silently assume this policy.

## Cloud design
The current standalone user directory is `%APPDATA%\Datacenter Tycoons`. It is shared
by local Windows users of the same OS account, not separated by Steam account.
Before enabling synchronization, introduce a Steam-account-specific save directory
with an explicit, non-destructive import from standalone saves. Do not simply sync
the current whole folder: that risks account mixing and uploading machine settings.

Proposed synchronized data: named slot JSON files, previous-good backups, thumbnails
and the slot index in the account's `saves` directory. Preserve autosave rotation.
Exclude settings/configuration outside the save directory, QA saves, logs, temporary
files, corrupt-test fixtures and executable caches. Define quota after measuring a
real library of saves; reserve headroom for thumbnails and backups.

Auto-Cloud can synchronize configured file groups at launch/exit without save API
calls, but paths, account isolation and conflict behavior still need implementation
and testing. [Official Steam Cloud documentation](https://partner.steamgames.com/doc/features/cloud).
Verify two devices, two Steam accounts on one Windows account, offline divergence,
conflicting edits, deleted slots and a failed upload before claiming Cloud support.

## Publication steps requiring the owner's Steamworks setup
Create the application; confirm legal developer/publisher identity, pricing and
release schedule; upload reviewed assets and build depots; complete required content
disclosures; configure supported features only after verification; run Steam's build
and store review. The supplied materials do not imply store approval or publication.
