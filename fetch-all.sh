#!/usr/bin/env bash

SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
OUTPUT_DIR_NAME=fetched
OUTPUT_DIR=${SCRIPT_DIR}/${OUTPUT_DIR_NAME}
OUTPUT_PDF_DIR=${SCRIPT_DIR}/pdf
IMAGE_EXT_PATTERN='(jpg|jpeg|png|webp)'

get_prefixed_number() {
    TO_RETURN=$1
    if [[ $TO_RETURN -lt 10 ]]; then
        TO_RETURN="000$TO_RETURN"
    elif [[ $TO_RETURN -lt 100 ]]; then
        TO_RETURN="00$TO_RETURN"
    elif [[ $TO_RETURN -lt 1000 ]]; then
        TO_RETURN="0$TO_RETURN"
    fi
    echo "${TO_RETURN}"
}

clean() {
    rm -rf "${SCRIPT_DIR:?}/${OUTPUT_DIR_NAME}" "${SCRIPT_DIR}/pdf" ${SCRIPT_DIR}/display_*
}

show_help() {
    echo "
    Usage: $0 [options]
    Options:
      -c  Clean: remove ${OUTPUT_DIR_NAME} and pdf dir
      -h  Show help
      -p  Generate pdf
      -r  Run the script
    
    For a correct script execution, you have to export some variables:
    export BASE_URL_PREFIX_1=\"https://your-base-url/prefix-\"
    export BASE_URL_PREFIX_2=\"https://your-base-url/prefix-\"
    export BASE_URL_SUFFIX=\"/\"
    export MAX_ITERATOR=200
    
    The url fetched will be BASE_URL_PREFIX_1 + iterator + BASE_URL_SUFFIX
    
    Once everything is Downloaded, you can launch a server to view all photos
    
    python3 -m http.server
    
    And then open the display.html from the browser
    open http://localhost:8000/display.html
    "
}

check_env() {
    if [[ -z ${BASE_URL_PREFIX_1} ]]; then
        echo "You must define BASE_URL_PREFIX_1 variable at least. If you have a second BASE_URL to fetch, you can use BASE_URL_PREFIX_2"
        show_help
        exit 1
    fi
    if [[ -z ${MAX_ITERATOR} ]]; then
        echo "You must define MAX_ITERATOR variable !"
        show_help
        exit 1
    fi
    if [[ -z ${MIN_ITERATOR} ]]; then
        echo "You must define MIN_ITERATOR variable !"
        show_help
        exit 1
    fi
    if [[ -z ${BASE_URL_SUFFIX} ]]; then
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
    export URL_TO_FETCH="${URL_PREFIX}${ITERATOR_CHAPTER}${BASE_URL_SUFFIX}"
    LIST=$(curl -s -L ${URL_TO_FETCH} | grep https | grep -E "${IMAGE_EXT_PATTERN}" | grep -oE '<meta property="og:image" content="https.*Tower Of God')
    if [[ -z ${LIST} ]]; then
        LIST=$(curl -s -L ${URL_TO_FETCH} | grep -oE '<a href="https://blogger.googleusercontent.com/img/[a-zA-Z0-9]*/[a-zA-Z0-9_-]*=[a-zA-Z0-9_-]*" ')
    fi
    if [[ -z ${LIST} ]]; then
      LIST=$(curl -s -L "${URL_TO_FETCH}" | grep https | grep -E "${IMAGE_EXT_PATTERN}" | grep -E 'image-|img')
    fi
    IFS=$'\n'
    for DIV in ${LIST}; do
        NEW_DIV="https${DIV#*https}"
        LINK="${NEW_DIV%%\"*}"
        NUM_CAPTURE=$(get_prefixed_number "${ITERATOR_LINK}")
        # TODO manage the extension based on ITERATOR_LINK
        RELATIVE_OUTPUT_FILE="${CHAPTER_NUM}-${NUM_CAPTURE}.jpg"
        OUTPUT_FILE="${OUTPUT_DIR}/${RELATIVE_OUTPUT_FILE}"
        curl -s "${LINK}" --output "${OUTPUT_FILE}" &
        ITERATOR_LINK=$((ITERATOR_LINK+1))
    done
}

run_script() {
    echo "Running the script..."
    check_env
    mkdir -p "${OUTPUT_DIR}"
    for ((ITERATOR_CHAPTER=MIN_ITERATOR; ITERATOR_CHAPTER<=MAX_ITERATOR; ITERATOR_CHAPTER++)); do
        CHAPTER_NUM=$(get_prefixed_number "${ITERATOR_CHAPTER}")
        echo "$CHAPTER_NUM"
        LIST=$(ls -lah "${OUTPUT_DIR}" | grep "${CHAPTER_NUM}-")
        if [[ -z ${LIST} ]] ; then
            fetch_chapter_num "${CHAPTER_NUM}" "${BASE_URL_PREFIX_1}" "${ITERATOR_CHAPTER}"
            sleep 1
        fi
        LIST=$(ls -lah "${OUTPUT_DIR}" | grep "${CHAPTER_NUM}-")
        if [[ -z ${LIST} ]] ; then
            echo "ERROR BASE_URL_PREFIX_1 ${CHAPTER_NUM}" >> error.txt
            fetch_chapter_num "${CHAPTER_NUM}" "${BASE_URL_PREFIX_2}" "${ITERATOR_CHAPTER}"
            sleep 1
        fi
        LIST=$(ls -lah "${OUTPUT_DIR}" | grep "${CHAPTER_NUM}-")
        if [[ -z ${LIST} ]] ; then
            echo "ERROR BASE_URL_PREFIX_2 ${CHAPTER_NUM}" >> error.txt
        fi
    done
}

pdf() {
    IMAGES_HTML_TO_ADD=""
    CHAPTER_FROM=$(get_prefixed_number "${MIN_ITERATOR}")
    mkdir -p "${OUTPUT_PDF_DIR}"
    for ((ITERATOR_CHAPTER=MIN_ITERATOR; ITERATOR_CHAPTER<=MAX_ITERATOR; ITERATOR_CHAPTER++)); do
        CHAPTER_NUM=$(get_prefixed_number "${ITERATOR_CHAPTER}")
        LIST=$(ls "${OUTPUT_DIR}" | grep "${CHAPTER_NUM}-")
        if [[ -z ${LIST} ]]; then
            echo "ERROR NOTHING FOR CHAPTER ${CHAPTER_NUM}" >> error.txt
        else
            IFS=$'\n'
            for IMAGES in ${LIST}; do
                IMAGES_HTML_TO_ADD="${IMAGES_HTML_TO_ADD}<img src=\"./${OUTPUT_DIR_NAME}/${IMAGES}\">"
            done

            if [[ $(( ITERATOR_CHAPTER % 3 )) -eq 0 || ${ITERATOR_CHAPTER} -eq ${MAX_ITERATOR} ]]; then
                OUTPUT_HTML="display_${CHAPTER_FROM}-${CHAPTER_NUM}.html"
                sed "s+IMAGES_HTML_TO_ADD+${IMAGES_HTML_TO_ADD}+g" display.template.html > "${OUTPUT_HTML}"
                wkhtmltopdf -T 0 -B 0 --page-height 1000mm "http://localhost:8000/${OUTPUT_HTML}" "${OUTPUT_PDF_DIR}/display_${CHAPTER_FROM}-${CHAPTER_NUM}.pdf" &
                NEXT_CHAPTER=$(( ITERATOR_CHAPTER + 1 ))
                CHAPTER_FROM=$(get_prefixed_number ${NEXT_CHAPTER})
                IMAGES_HTML_TO_ADD=""
            fi
        fi
    done
}

[ $# -eq 0 ] && show_help && exit 0
while getopts ":hrpc:" option; do
    case "${option}" in
        h)
            show_help
            ;;
        r)
            run_script
            ;;
        p)
            pdf
            ;;
        c)
            clean
            ;;
        *)
            echo "Invalid option: -${OPTARG}" >&2
            show_help
            exit 1
    esac
done
