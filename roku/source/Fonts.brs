' Open Font License — Outfit by Rodrigo Fuenzalida / Google Fonts
' https://fonts.google.com/specimen/Outfit
'
' Usage in SceneGraph XML:
'   <Label text="Title">
'     <Font role="font" uri="pkg:/fonts/Outfit-Bold.ttf" size="48" />
'   </Label>
'
' Or from BrightScript:
'   label.font = MakeFont("pkg:/fonts/Outfit-Bold.ttf", 48)
function MakeFont(uri as String, size as Integer) as Object
    font = createObject("roSGNode", "Font")
    font.uri = uri
    font.size = size
    return font
end function

function FontBrand(size = 36 as Integer) as Object
    return MakeFont("pkg:/fonts/Outfit-Bold.ttf", size)
end function

function FontTitle(size = 52 as Integer) as Object
    return MakeFont("pkg:/fonts/Outfit-Bold.ttf", size)
end function

function FontBody(size = 24 as Integer) as Object
    return MakeFont("pkg:/fonts/Outfit-Regular.ttf", size)
end function

function FontMeta(size = 20 as Integer) as Object
    return MakeFont("pkg:/fonts/Outfit-Medium.ttf", size)
end function

function FontUi(size = 26 as Integer) as Object
    return MakeFont("pkg:/fonts/Outfit-SemiBold.ttf", size)
end function
