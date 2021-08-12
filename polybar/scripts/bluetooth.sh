
STATUS=$(rofi-bluetooth --status)
SPLIT_STATUS=($(echo $STATUS | tr ";" "\n"))
if [ "$STATUS" == "" ]; then
	ICON="%{F#EC7875} "
elif [ "$STATUS" == "" ]; then
    ICON="%{F#42A5F5} %{F-}"
else
    ICON="%{F#42A5F5} %{F-}${SPLIT_STATUS[1]}"
fi
echo $ICON

