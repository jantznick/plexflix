' Hardcoded Cable VCNs for this Chicago OTA lineup.
' Locals from the tuner screenshots: 2/5/7/9/11/23/24/26/32/38/44/48/50/60/62/66.
' Matching Cable nets sit at major.15 (between .1 and .2). Everything else fills
' unused majors so the guide is one interleaved list — not a 70+/800 dump.

function GetHardcodedCableLineup() as Object
    out = {}

    ' —— Sit next to the matching OTA primary ——
    out["timst-cbs"] = 2.15
    out["timst-nbc"] = 5.15
    out["timst-abc"] = 7.15
    out["timst-cw"] = 9.15
    out["timst-fox"] = 32.15
    out["timst-telemundo"] = 44.15
    out["timst-wapa-america"] = 44.25
    out["timst-wapa-deportes"] = 44.35

    ' —— News / docs (unused major 4) ——
    out["timst-cnbc"] = 4.1
    out["timst-bbc-america"] = 4.2

    ' —— Kids (unused major 12, after PBS 11.x) ——
    out["timst-cartoon-network"] = 12.1
    out["timst-boomerang"] = 12.2
    out["timst-nickelodeon"] = 12.3
    out["timst-nick-jr"] = 12.4
    out["timst-nicktoons"] = 12.5
    out["timst-teenick"] = 12.6
    out["timst-disney-channel"] = 12.7
    out["timst-disney-junior"] = 12.8
    out["timst-disney-xd"] = 12.9
    out["timst-cbeebies"] = 12.10
    out["timst-discovery-family"] = 12.11
    out["timst-starz-kids-and-family"] = 12.12

    ' —— General entertainment (unused majors 14–18) ——
    out["timst-usa-network"] = 14.1
    out["timst-syfy"] = 14.2
    out["timst-tnt"] = 14.3
    out["timst-tbs"] = 14.4
    out["timst-trutv"] = 14.5
    out["timst-amc"] = 14.6
    out["timst-fx"] = 15.1
    out["timst-fxx"] = 15.2
    out["timst-fxm"] = 15.3
    out["timst-freeform"] = 15.4
    out["timst-bravo"] = 15.5
    out["timst-comedy-central"] = 15.6
    out["timst-ae-network"] = 15.7
    out["timst-mtv"] = 15.8
    out["timst-axs-tv"] = 16.1
    out["timst-discovery-channel"] = 17.1
    out["timst-animal-planet"] = 17.2
    out["timst-american-heroes-channel"] = 17.3
    out["timst-discovery-turbo"] = 17.4
    out["timst-food-network"] = 17.5
    out["timst-hgtv"] = 17.6
    out["timst-fox-deportes"] = 18.1

    ' —— Premium (unused majors 28–30, before FOX 32) ——
    out["timst-hbo"] = 28.1
    out["timst-hbo-comedy"] = 28.2
    out["timst-hbo-drama"] = 28.3
    out["timst-hbo-movies"] = 28.4
    out["timst-hbo-latino"] = 28.5
    out["timst-showtime"] = 29.1
    out["timst-showtime-2"] = 29.2
    out["timst-showtime-extreme"] = 29.3
    out["timst-showtime-family-zone"] = 29.4
    out["timst-showtime-next"] = 29.5
    out["timst-showtime-women"] = 29.6
    out["timst-starz"] = 30.1
    out["timst-starz-cinema"] = 30.2
    out["timst-starz-comedy"] = 30.3

    return out
end function

' Display-title aliases → same VCNs as above.
function GetHardcodedCableTitleNumbers() as Object
    out = {}
    out["cbs"] = 2.15
    out["nbc"] = 5.15
    out["abc"] = 7.15
    out["cw"] = 9.15
    out["the cw"] = 9.15
    out["fox"] = 32.15
    out["telemundo"] = 44.15
    out["wapa america"] = 44.25
    out["wapa"] = 44.25
    out["wapa deportes"] = 44.35
    out["cnbc"] = 4.1
    out["bbc america"] = 4.2
    out["bbca"] = 4.2
    out["cartoon network"] = 12.1
    out["boomerang"] = 12.2
    out["nickelodeon"] = 12.3
    out["nick"] = 12.3
    out["nick jr"] = 12.4
    out["nick jr."] = 12.4
    out["nicktoons"] = 12.5
    out["teenick"] = 12.6
    out["teen nick"] = 12.6
    out["disney channel"] = 12.7
    out["disney"] = 12.7
    out["disney junior"] = 12.8
    out["disney xd"] = 12.9
    out["cbeebies"] = 12.10
    out["discovery family"] = 12.11
    out["starz kids"] = 12.12
    out["starz kids and family"] = 12.12
    out["usa"] = 14.1
    out["usa network"] = 14.1
    out["syfy"] = 14.2
    out["tnt"] = 14.3
    out["tbs"] = 14.4
    out["trutv"] = 14.5
    out["tru tv"] = 14.5
    out["amc"] = 14.6
    out["fx"] = 15.1
    out["fxx"] = 15.2
    out["fxm"] = 15.3
    out["fx movie"] = 15.3
    out["freeform"] = 15.4
    out["bravo"] = 15.5
    out["comedy central"] = 15.6
    out["ae"] = 15.7
    out["a&e"] = 15.7
    out["a and e"] = 15.7
    out["mtv"] = 15.8
    out["axs tv"] = 16.1
    out["axs"] = 16.1
    out["discovery"] = 17.1
    out["discovery channel"] = 17.1
    out["animal planet"] = 17.2
    out["american heroes channel"] = 17.3
    out["ahc"] = 17.3
    out["discovery turbo"] = 17.4
    out["food network"] = 17.5
    out["hgtv"] = 17.6
    out["fox deportes"] = 18.1
    out["hbo"] = 28.1
    out["hbo comedy"] = 28.2
    out["hbo drama"] = 28.3
    out["hbo movies"] = 28.4
    out["hbo latino"] = 28.5
    out["showtime"] = 29.1
    out["showtime 2"] = 29.2
    out["showtime extreme"] = 29.3
    out["showtime family zone"] = 29.4
    out["showtime next"] = 29.5
    out["showtime women"] = 29.6
    out["starz"] = 30.1
    out["starz cinema"] = 30.2
    out["starz comedy"] = 30.3
    return out
end function
