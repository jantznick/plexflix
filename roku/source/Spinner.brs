' BusySpinner draws its poster at the image's own pixel size rather than at a
' size expressed in layout units. Those only coincide when the UI is rendered
' 1:1 at 1920x1080, so anywhere else — a 720p device, or the simulator scaling
' the frame into a window — the spinner's footprint is wider than the 96px
' image and a hand-centred translation ends up right of centre by half the
' difference.
'
' Pinning the poster to the design size makes the footprint predictable, which
' is what lets SpinnerCenterX below be exact.
function SpinnerSize() as Integer
    return 96
end function

sub PinSpinner(spinner as Object)
    if spinner = invalid then return
    poster = spinner.poster
    if poster = invalid then return
    size = SpinnerSize()
    poster.width = size
    poster.height = size
end sub

' Left edge that centres a pinned spinner on centerX
function SpinnerCenterX(centerX as Integer) as Integer
    return centerX - Int(SpinnerSize() / 2)
end function

' Centres from what the spinner actually measures once it has been rendered,
' falling back to the pinned size before then. Belt and braces: if a firmware
' will not let the poster be pinned, this still lands it on the right axis.
'
' Only the horizontal axis is touched. Where the spinner sits vertically is a
' layout decision and stays with the XML that declared it.
sub CenterSpinner(spinner as Object, centerX as Integer)
    if spinner = invalid then return

    width = SpinnerSize()
    rect = spinner.boundingRect()
    ' Ignore the zero it reports before the first render, and anything absurd
    if rect <> invalid and rect.width > 40 and rect.width < 400 then
        width = rect.width
    end if

    top = 0
    current = spinner.translation
    if current <> invalid and current.count() > 1 then top = current[1]

    spinner.translation = [centerX - Int(width / 2), top]
end sub
