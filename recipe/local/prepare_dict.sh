#!/bin/bash
# Apache 2.0

corpus=$1
if [ -z "$corpus" ] ; then
    echo >&2 "The script $0 expects one parameter -- the location of the corpus"
    exit 1
fi
if [ ! -d "$corpus" ] ; then
    echo >&2 "The directory $corpus does not exist"
fi

mkdir -p data_words/lang data_words/local/dict data_phones/lang data_phones/local/dict

cp $corpus/lang/dict/lexicon_words.txt data_words/local/dict/lexicon.txt
cp $corpus/lang/dict/lexicon_phones.txt data_phones/local/dict/lexicon.txt

cat data_words/local/dict/lexicon.txt | \
    perl -ane 'print join("\n", @F[1..$#F]) . "\n"; '  | \
    sort -u | grep -v 'SIL' > data_words/local/dict/nonsilence_phones.txt

cat data_phones/local/dict/lexicon.txt | \
    perl -ane 'print join("\n", @F[1..$#F]) . "\n"; '  | \
    sort -u | grep -v 'SIL' > data_phones/local/dict/nonsilence_phones.txt

touch data_words/local/dict/extra_questions.txt
touch data_words/local/dict/optional_silence.txt

touch data_phones/local/dict/extra_questions.txt
touch data_phones/local/dict/optional_silence.txt

echo "SIL"   > data_words/local/dict/optional_silence.txt
echo "SIL"   > data_words/local/dict/silence_phones.txt
echo "<UNK>" > data_words/local/dict/oov.txt

echo "SIL"   > data_phones/local/dict/optional_silence.txt
echo "SIL"   > data_phones/local/dict/silence_phones.txt
echo "<UNK>" > data_phones/local/dict/oov.txt

echo "Dictionary preparation succeeded"
