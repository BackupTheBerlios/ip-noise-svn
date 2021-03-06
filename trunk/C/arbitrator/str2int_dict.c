#ifndef __KERNEL__

#include <string.h>
#include <stdlib.h>
#else
#include "k_stdlib.h"
#define strncasecmp(a,b,len) (strnicmp((a),(b),(len)))
#endif


#include "iface.h"


struct str2int_dict_elem_struct
{
    ip_noise_id_t name;
    int index;
};

typedef struct str2int_dict_elem_struct dict_elem;

static int str2int_dict_compare(const void * void_key1, const void * void_key2, const void * context)
{
    dict_elem * key1;
    dict_elem * key2;

    key1 = (dict_elem *)void_key1;
    key2 = (dict_elem *)void_key2;

    return strncasecmp(key1->name, key2->name, sizeof(ip_noise_id_t));
}

ip_noise_str2int_dict ip_noise_str2int_dict_alloc(void)
{
    ip_noise_str2int_dict dict;
    dict = rbinit(str2int_dict_compare, NULL);

    return dict;
}

int ip_noise_str2int_dict_get(ip_noise_str2int_dict dict, char * name)
{
    dict_elem myelem;
    dict_elem * ret;
    
    strncpy(myelem.name, name, sizeof(myelem.name));
    ret = (dict_elem *)rbfind(&myelem, dict);
    if (ret == NULL)
    {
        return -1;
    }
    else
    {
        return ret->index;
    }
}

void ip_noise_str2int_dict_add(
    ip_noise_str2int_dict dict, 
    char * name, 
    int index)
{
    dict_elem * myelem;

    myelem = (dict_elem *)malloc(sizeof(dict_elem));

    strncpy(myelem->name, name, sizeof(myelem->name));
    myelem->index = index;

    rbsearch(myelem, dict);
}

void ip_noise_str2int_dict_remove(ip_noise_str2int_dict dict, char * name)
{
    dict_elem myelem;

    strncpy(myelem.name, name, sizeof(myelem.name));
    rbdelete(&myelem, dict);    
}

void ip_noise_str2int_dict_reset(ip_noise_str2int_dict dict)
{
    dict_elem * myelem;

    myelem = (dict_elem *)rbmin(dict);
    while (myelem != NULL)
    {
        rbdelete(myelem, dict);
        /* rbdelete calls free implicitly */
#if 0
        free(myelem); 
#endif
        myelem = (dict_elem *)rbmin(dict);
    }
}

void ip_noise_str2int_dict_free(ip_noise_str2int_dict dict)
{
    ip_noise_str2int_dict_reset(dict);
    rbdestroy(dict);
}

static void duplicate_key(const void * void_elem, const VISIT which, const int depth, void * new)
{
    dict_elem * elem = (dict_elem *)void_elem;
    ip_noise_str2int_dict_add(new, elem->name, elem->index);
}

ip_noise_str2int_dict ip_noise_str2int_dict_duplicate(ip_noise_str2int_dict old)
{
    ip_noise_str2int_dict new;

    new = ip_noise_str2int_dict_alloc();

    rbwalk(old, duplicate_key, new);

    return new;
}
