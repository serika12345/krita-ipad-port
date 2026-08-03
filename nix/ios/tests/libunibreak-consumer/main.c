#include <eastasianwidthdef.h>
#include <graphemebreak.h>
#include <linebreak.h>
#include <linebreakdef.h>
#include <unibreakbase.h>
#include <unibreakdef.h>
#include <wordbreak.h>

#if UNIBREAK_VERSION != 0x0700
#  error "The Krita iOS libunibreak contract requires version 7.0"
#endif

int main(void)
{
    static const utf8_t text[] = {'A', ' ', 'B'};
    char line_breaks[sizeof(text)];
    char grapheme_breaks[sizeof(text)];
    char word_breaks[sizeof(text)];

    set_linebreaks_utf8(text, sizeof(text), "en", line_breaks);
    set_graphemebreaks_utf8(text, sizeof(text), "en", grapheme_breaks);
    set_wordbreaks_utf8(text, sizeof(text), "en", word_breaks);

    return unibreak_version != UNIBREAK_VERSION || ub_get_char_eaw_class(text[0]) < 0;
}
