#!/bin/bash

get_prefixed_number() {
    TO_RETURN=$1
    if [[ $TO_RETURN -lt 10 ]]; then
        TO_RETURN="000$TO_RETURN"
    elif [[ $TO_RETURN -lt 100 ]]; then
        TO_RETURN="00$TO_RETURN"
    elif [[ $TO_RETURN -lt 1000 ]]; then
        TO_RETURN="0$TO_RETURN"
    fi
    echo $TO_RETURN
}

show_help() {
    echo "Usage: $0 [options]"
    echo "Options:"
    echo "  -h  Show help"
    echo "  -r  Run the script"
    echo ""
    echo "For a correct script execution, you have to export some variables:"
    echo "export BASE_URL_PREFIX_1=\"https://your-base-url/prefix-\""
    echo "export BASE_URL_PREFIX_2=\"https://your-base-url/prefix-\""
    echo "export BASE_URL_SUFFIX=\"/\""
    echo "export MAX_ITERATOR=200"
    echo ""
    echo "The url fetched will be BASE_URL_PREFIX_1 + iterator + BASE_URL_SUFFIX"
    echo ""
    echo "Once everything is Downloaded, you can launch a server to view all photos"
    echo ""
    echo "python3 -m http.server"
    echo ""
    echo "And then open the display.html from the browser"
    echo "open http://localhost:8000/display.html"
}

check_env() {
    if [[ -z $BASE_URL_PREFIX_1 ]]; then
        echo "You must define BASE_URL_PREFIX_1 variable at least. If you have a second BASE_URL to fetch, you can use BASE_URL_PREFIX_2"
        show_help
        exit 1
    fi
    if [[ -z $MAX_ITERATOR ]]; then
        echo "You must define MAX_ITERATOR variable !"
        show_help
        exit 1
    fi
    if [[ -z $BASE_URL_SUFFIX ]]; then
        echo "You must define BASE_URL_SUFFIX variable !"
        show_help
        exit 1
    fi
}

fetch_chapter_num() {
    CHAPTER_NUM=$1
    URL_PREFIX=$2
    ITERATOR_CHAPTER=$3
    ITERATOR_LINK=0
    export URL_TO_FETCH=${URL_PREFIX}${ITERATOR_CHAPTER}${BASE_URL_SUFFIX}
    LIST=$(curl -s -L ${URL_TO_FETCH} | grep https | grep -E '(jpg|jpeg)' | grep image-)
    if [[ -z $LIST ]]; then
        LIST=$(curl -s -L ${URL_TO_FETCH} | grep https | grep -E '(jpg|jpeg)' | grep img)
    fi
    IFS=$'\n'
    for DIV in $LIST; do
        NEW_DIV=https$(echo "${DIV#*https}")
        LINK=$(echo "${NEW_DIV%%\"*}")
        NUM_CAPTURE=$(get_prefixed_number $ITERATOR_LINK)
        curl -s $LINK --output "./fetched/${CHAPTER_NUM}-${NUM_CAPTURE}.jpg"
        ITERATOR_LINK=$((ITERATOR_LINK+1))
    done
}

run_script() {
    echo "Running the script..."
    check_env
    mkdir -p fetched
    for ((ITERATOR_CHAPTER=0; ITERATOR_CHAPTER<=${MAX_ITERATOR}; ITERATOR_CHAPTER++)); do
        CHAPTER_NUM=$(get_prefixed_number ${ITERATOR_CHAPTER})
        echo $CHAPTER_NUM
        LIST=$(ls -lah ./fetched | grep "${CHAPTER_NUM}-")
        if [[ -z $LIST ]] ; then
            fetch_chapter_num ${CHAPTER_NUM} ${BASE_URL_PREFIX_1} ${ITERATOR_CHAPTER}
        fi
        LIST=$(ls -lah ./fetched | grep "${CHAPTER_NUM}-")
        if [[ -z $LIST ]] ; then
            echo "ERROR BASE_URL_PREFIX_1 $CHAPTER_NUM" >> error.txt
            fetch_chapter_num ${CHAPTER_NUM} ${BASE_URL_PREFIX_2} ${ITERATOR_CHAPTER}
        fi
        LIST=$(ls -lah ./fetched | grep "${CHAPTER_NUM}-")
        if [[ -z $LIST ]] ; then
            echo "ERROR BASE_URL_PREFIX_2 $CHAPTER_NUM" >> error.txt
        fi
    done
}

while getopts ":hr" option; do
    case "$option" in
        h)
            show_help
            exit 0
            ;;
        r)
            run_script
            exit 0
            ;;
        \?)
            echo "Invalid option: -$OPTARG" >&2
            show_help
            exit 1
            ;;
    esac
done

show_help
