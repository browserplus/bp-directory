/**
 * ***** BEGIN LICENSE BLOCK *****
 * The contents of this file are subject to the Mozilla Public License
 * Version 1.1 (the "License"); you may not use this file except in
 * compliance with the License. You may obtain a copy of the License at
 * http://www.mozilla.org/MPL/
 * 
 * Software distributed under the License is distributed on an "AS IS"
 * basis, WITHOUT WARRANTY OF ANY KIND, either express or implied. See the
 * License for the specific language governing rights and limitations
 * under the License.
 * 
 * The Original Code is BrowserPlus (tm).
 * 
 * The Initial Developer of the Original Code is Yahoo!.
 * Portions created by Yahoo! are Copyright (C) 2006-2009 Yahoo!.
 * All Rights Reserved.
 * 
 * Contributor(s): 
 * ***** END LICENSE BLOCK ***** */

#include "bpservice/bpservice.h"
#include "bpservice/bpcallback.h"
#include "bpfile/bpfile.h"
#include <map>

#if defined(WIN32)
#include <windows.h>
#endif

using namespace std;
using namespace bp::file;
using namespace bplus::service;
namespace bfs = boost::filesystem;

const size_t kDefaultLimit = 1000;

// A visitor class for list() and listWithStructure().  Applies
// filtering, enforces max nodes visited, and builds up a 
// bplus::List* of matched nodes.
//
class ListVisitor : public IVisitor {
public:
    ListVisitor(bool flat)
        :  m_flat(flat), m_mimeTypes(), m_limit(kDefaultLimit),
           m_cb(NULL), m_visited(0), m_topList(new bplus::List)  {
    }

    virtual ~ListVisitor() {
        if (m_topList) {
            delete m_topList;
        }
        if (m_cb) {
            delete m_cb;
        }
    }

    IVisitor::tResult visitNode(const Path& p,
                                const Path& relPath) {
        // enforce max nodes visited
        if (m_visited++ >= m_limit) {
            return eStop;
        }

        // apply mimetype filtering
        if (isMimeType(p, m_mimeTypes)) {
            if (m_cb) {
                bplus::Map m;
                m.add("path", new bplus::Path(p.externalUtf8()));
                if (!m_flat) {
                    m.add("relativeName",
                          new bplus::String(relPath.externalUtf8()));
                }
                m_cb->invoke(m);
            }

            // add this child
            addChild(p, relPath);
        }
        return eOk;
    }

    void setMimeTypes(const set<string> mt) { m_mimeTypes = mt; }
    void setCallback(const Callback& cb) { m_cb = new Callback(cb); }
    void setLimit(size_t l) { m_limit = l; }

    void addChild(const Path& p,
                  const Path& relPath) {
        if (p.empty() || relPath.empty()) {
            // yea, right
            return;
        }

        // flat heirarchy is easy, only one list
        if (m_flat) {
            m_topList->append(new bplus::Path(p.externalUtf8()));
            return;
        }

        // find list for relpath parent, creating any needed 
        // lists along the way.
        bplus::List* theList = NULL;
        Path relParent = relPath.parent_path();
        if (relParent.empty()) {
            theList = m_topList;
        } else {
            Path tpath;
            for (tBase::iterator it = relParent.begin(); it != relParent.end(); ++it) {
                tpath /= *it;
                if (m_listMap.find(tpath) == m_listMap.end()) {
                    // no list for tpath, so it must be added to heirarchy
                    bplus::Map* m = new bplus::Map;
                    m->add("relativeName", new bplus::String(tpath.externalUtf8()));
                    m->add("path", new bplus::Path(tpath.externalUtf8()));
                    bplus::List* kids = new bplus::List;
                    m->add("children", kids);
                    m_listMap[tpath] = kids;
                    Path tparent = tpath.parent_path();
                    if (tparent.empty()) {
                        m_topList->append(m);
                    } else {
                        m_listMap[tparent]->append(m);
                    }
                }
            }
            theList = m_listMap[relParent];
        }

        // now add this node to list.  if it's a dir,
        // also add new list to m_listMap
        bplus::Map* m = new bplus::Map;
        m->add("relativeName", new bplus::String(relPath.externalUtf8()));
        m->add("path", new bplus::Path(p.externalUtf8()));
        if (bfs::is_directory(p)) {
            bplus::List* kids = new bplus::List;
            m->add("children", kids);
            m_listMap[relPath] = kids;
        }
        theList->append(m);
    }

    bplus::List* adoptKids() {
        bplus::List* l = m_topList;
        m_topList = NULL;
        return l;
    }

private:
    bool m_flat;
    set<string> m_mimeTypes;
    size_t m_limit;
    Callback* m_cb;
    size_t m_visited;
    map<Path, bplus::List*> m_listMap; // aliases into m_topList structure
    bplus::List* m_topList; 
};
    

// our service
//
class Directory : public Service
{
public:
    BP_SERVICE(Directory);
    
    Directory() : Service() {
    }
    ~Directory() {
    }

    void list(const Transaction& tran, 
              const bplus::Map& args);

    void listWithStructure(const Transaction& tran, 
                           const bplus::Map& args);

private:
    void doList(const Transaction& tran, 
                const bplus::Map& args,
                bool flat);
};

BP_SERVICE_DESC(Directory, "Directory", "1.0.0",
                "Lets you snort about in directories.")
ADD_BP_METHOD(Directory, list,
              "Returns a list of filehandles for the directories contents.")
ADD_BP_METHOD_ARG(list, "directory", Path, true, 
                  "Directory to traverse.")
ADD_BP_METHOD_ARG(list, "followLinks", Boolean, false, 
                  "If true, symbolic links will be followed. Default is true.")
ADD_BP_METHOD_ARG(list, "mimetypes", List, false, 
                  "Optional list of mimetype filters to apply (e.g."
                  "[\"image/jpeg\"]")
ADD_BP_METHOD_ARG(list, "limit", Integer, false, 
                  "Maximum number of items to examine.  Default is 1000.")
ADD_BP_METHOD_ARG(list, "callback", CallBack, false, 
                  "Optional callback with will be invoked with each path.")

ADD_BP_METHOD(Directory, listWithStructure,
              "Returns a nested list of filehandles for the directories "
              "contents.")
ADD_BP_METHOD_ARG(listWithStructure, "directory", Path, true, 
                  "Directory to traverse.")
ADD_BP_METHOD_ARG(listWithStructure, "followLinks", Boolean, false, 
                  "If true, symbolic links will be followed. Default is true.")
ADD_BP_METHOD_ARG(listWithStructure, "mimetypes", List, false, 
                  "Optional list of mimetype filters to apply (e.g."
                  "[\"image/jpeg\"]")
ADD_BP_METHOD_ARG(listWithStructure, "limit", Integer, false, 
                  "Maximum number of items to examine.  Default is 1000.")
ADD_BP_METHOD_ARG(listWithStructure, "callback", CallBack, false, 
                  "Optional callback with will be invoked with each path.")
END_BP_SERVICE_DESC


void
Directory::list(const Transaction& tran, 
                const bplus::Map& args)
{
    doList(tran, args, true);
}


void
Directory::listWithStructure(const Transaction& tran, 
                             const bplus::Map& args)
{
    doList(tran, args, false);
}


// here come's the heavy lifting...
void
Directory::doList(const Transaction& tran, 
                  const bplus::Map& args,
                  bool flat)
{
    try {
        ListVisitor v(flat);

        // dig out args

        // directory, required
        const bplus::Path* uri =
            dynamic_cast<const bplus::Path*>(args.value("directory"));
        if (!uri) {
            throw string("required directory parameter missing");
        }
        Path path = pathFromURL((string)*uri);
        
        // followLinks, optional
        bool followLinks = true;
        (void) args.getBool("followLinks", followLinks);

        // mimetypes, optional
        set<string> mimeTypes;
        const bplus::List* l = NULL;
        (void) args.getList("mimetypes", l);
        if (l) {
            for (size_t i = 0; i < l->size(); i++) {
                const bplus::String* s =
                    dynamic_cast<const bplus::String*>(l->value(i));
                if (s) {
                    mimeTypes.insert(s->value());
                }
            }
            v.setMimeTypes(mimeTypes);
        }

        // limit, optional
        int limit = kDefaultLimit;
        (void) args.getInteger("limit", limit);
        v.setLimit(limit);

        // callback, optional
        const bplus::CallBack* cb =
            dynamic_cast<const bplus::CallBack*>(args.value("callback"));
        if (cb) {
            v.setCallback(Callback(tran, *cb));
        }

        // do the visit, result in v.kids()
        recursiveVisit(path, v, followLinks);

        // return massive success
        bplus::Map results;
        results.add("success", new bplus::Bool(true));
        results.add("contents", v.adoptKids());
        tran.complete(results);

    } catch (const string& msg) {
        // one of our exceptions
        log(BP_DEBUG, "Directory::list(), catch " + msg);
        tran.error("directoryError", msg.c_str());

    } catch (const tFileSystemError& e) {
        // a boost::filesystem exception
        string msg = string("Directory::list(), catch boost::filesystem")
                     + " exception, path1: '" 
                     + Path(e.path1()).utf8()
                     +", path2: '" + Path(e.path2()).utf8()
                     + "' (" + e.what() + ")";
        log(BP_ERROR, "Directory: " + msg);
        tran.error("directoryError", msg.c_str());
    }
}

