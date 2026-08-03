#include <libintl.h>

#include <locale.h>
#include <stddef.h>

#if !defined(__aarch64__) && !defined(__arm64__)
#  error "The Krita iOS libintl consumer must compile for arm64"
#endif

int main(int argc, char **argv)
{
    const char *domain = "krita-ios-libintl-check";
    const char *message = argc > 0 ? argv[0] : "Krita";

    const char *domain_directory = bindtextdomain(domain, NULL);
    const char *active_domain = textdomain(domain);
    const char *translated = gettext(message);
    const char *domain_translated = dgettext(domain, message);
    const char *category_translated = dcgettext(domain, message, LC_MESSAGES);
    const char *plural_translated = ngettext("brush", "brushes", (unsigned long)argc);

    return domain_directory == NULL || active_domain == NULL || translated == NULL
            || domain_translated == NULL || category_translated == NULL
            || plural_translated == NULL;
}
