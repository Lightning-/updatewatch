#!/bin/bash

BNAME=$(basename $0)
DNAME=$(dirname $0)



# load default settings
. "$DNAME/defaults"

# load custom settings if available
[[ -r "$DNAME/settings" ]] && . "$DNAME/settings"

# create feed directory
[[ -d "feed-data" ]] || mkdir "feed-data"

# create temporary directory
[[ -d "tmp" ]] || mkdir "tmp"



declare -a GITS="${GIT_DIRS:-(release-data)}"
declare -a RESULTS=("${TEMPLATE:=jira}-bash")



for gitdir in "${GITS[@]}"
do
	git -C "$DNAME" -C "$gitdir" pull || exit $?
done

readarray -t FEEDS < <("$DNAME"/field_getter.rb "${CONFIG:-config.yaml}" feed | sort -u)

for feed in "${FEEDS[@]}"
do
	"$DNAME"/feed_transformer.rb "$feed" || exit $?
done



readarray -t FILES < <("$DNAME"/field_getter.rb | sort -u)

if ([[ -v APIBULK ]] && [[ -n "$APIBULK" ]])
then
	for file in "${FILES[@]}"
	do
		if REQUEST=$("$DNAME"/generate_changerequest.rb -b -s "$file" ${REQARGS:-})
		then
			if ! grep -F -q "no updates available" <<< "$REQUEST"
			then
				if grep -F -q "issueUpdates" <<< "$REQUEST"
				then
					if RESULTS+=("$(curl -k -s -H "Authorization: Bearer $TOKEN" -H "Content-Type: application/json" -H "Accept: application/json" -X POST -d @- "$THOST$APIBULK" <<< "$REQUEST")")
					then
						cp -f "$file" tmp/ || exit $?
					else
						exit $?
					fi
				else
					if RESULTS+=("$(curl -k -s -H "Authorization: Bearer $TOKEN" -H "Content-Type: application/json" -H "Accept: application/json" -X POST -d @- "$THOST$API" <<< "$REQUEST")")
					then
						cp -f "$file" tmp/ || exit $?
					else
						exit $?
					fi
				fi
			fi
		else
			exit $?
		fi
	done
else
	for file in "${FILES[@]}"
	do
		readarray -d '' -t REQUESTS < <("$DNAME"/generate_changerequest.rb -s "$file" ${REQARGS:-} || printf 'ERROR: %s\n' $?)

		if ([[ -v REQUESTS ]] && [[ -n "${REQUESTS[@]}" ]])
		then
			for request in "${REQUESTS[@]}"
			do
				if ! grep -q "^ERROR:" <<< "$request"
				then
					if ! grep -F -q "no updates available" <<< "$request"
					then
						if RESULTS+=("$(curl -k -s -H "Authorization: Bearer $TOKEN" -H "Content-Type: application/json" -H "Accept: application/json" -X POST -d @- "$THOST$API" <<< "$request")")
						then
							cp -f "$file" tmp/ || exit $?
						else
							exit $?
						fi
					fi
				else
					exit 4
				fi
			done
		else
			exit 4
		fi
	done
fi



"$DNAME"/generate_callback.rb "${RESULTS[@]}" || exit $?

if ([[ -v CALLBACK ]] && [[ -n "$CALLBACK" ]] && [[ -v CSTYLE ]] && [[ -n "$CSTYLE" ]])
then
	RESULTS[0]="$TEMPLATE-$CSTYLE"

	if ([[ -v TBASE ]] && [[ -n "$TBASE" ]])
	then
		export TBASEURL="$THOST$TBASE"
	fi

	if CBACK=$("$DNAME"/generate_callback.rb "${RESULTS[@]}")
	then
		if ! grep -F -q "no updates available" <<< "$CBACK"
		then
			curl -k -s -H "Authorization: Bearer $CTOKEN" -H "Content-Type: application/json" -H "Accept: application/json" -H "OCS-APIRequest: true" -X POST -d @- "$CALLBACK" <<< "$CBACK" || exit $?
		fi
	else
		exit $?
	fi
fi



exit 0
