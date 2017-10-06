#!/bin/bash
# Apache 2.0

corpus=$1
set -e -o pipefail
if [ -z "$corpus" ] ; then
    echo >&2 "The script $0 expects one parameter -- the location of the corpus"
    exit 1
fi
if [ ! -d "$corpus" ] ; then
    echo >&2 "The directory $corpus does not exist"
fi

echo "Preparing train and test data"
mkdir -p data_words data_words/local data_words/train data_words/dev data_phones data_phones/local data_phones/train data_phones/dev

for x in train dev; do
    echo "Copy spk2utt, utt2spk, wav.scp, text for $x"
    cp $corpus/data/$x/text     data_words/$x/text    || exit 1;
    cp $corpus/data/$x/spk2utt  data_words/$x/spk2utt || exit 1;
    cp $corpus/data/$x/utt2spk  data_words/$x/utt2spk || exit 1;
    cp $corpus/data/$x/text     data_phones/$x/text    || exit 1;
    cp $corpus/data/$x/spk2utt  data_phones/$x/spk2utt || exit 1;
    cp $corpus/data/$x/utt2spk  data_phones/$x/utt2spk || exit 1;

    # the corpus wav.scp contains physical paths, so we just re-generate
    # the file again from scratch instead of figuring out how to edit it
    for rec in $(awk '{print $1}' $corpus/data/$x/text) ; do
        cmd=${rec%%_*}
        filename=audio/$cmd/${rec#*_}.wav
        if [ ! -f "$filename" ] ; then
            echo >&2 "The file $filename could not be found ($rec)"
            exit 1
        fi
        # we might want to store physical paths as a general rule
        #filename=$(readlink -f $filename)
        echo "$rec $filename"
    done > data_words/$x/wav.scp
    cp data_words/$x/wav.scp data_phones/$x/wav.scp

    # fix_data_dir.sh fixes common mistakes (unsorted entries in wav.scp,
    # duplicate entries and so on). Also, it regenerates the spk2utt from
    # utt2sp
    utils/fix_data_dir.sh data_words/$x
    utils/fix_data_dir.sh data_phones/$x
done

echo "Data preparation completed."
