#!/usr/bin/env hy

(import re
        codecs
        [apiclient.discovery [build]]
        [apiclient.errors [HttpError]]
        [oauth2client.tools [argparser]])

(setv DEVELOPER-KEY "")
(setv SERVICE-NAME "youtube")
(setv API-VERSION "v3")

(defn youtube-search [options]
  (setv youtube (build SERVICE-NAME
                       API-VERSION
                       :developerKey DEVELOPER-KEY))
  (setv video-ids options.id)
  (setv video-response (-> (.videos youtube)
                           (.list :id video-ids :part "snippet,statistics")
                           (.execute)))
  (setv videos [])

  (for [result (.get video-response "items")]
    (.append videos
             (.format "{}\t{}\t{}\t{}\t{}"
                      (-> result (get "snippet") (get "title"))
                      (-> result (get "snippet") (get "channelTitle"))
                      (-> result (get "statistics") (get "viewCount"))
                      (-> result (get "statistics") (get "likeCount"))
                      (-> result (get "statistics") (get "dislikeCount")))))

  (setv header "Title\tChannel\tView count\tLike count\tDislike count\n")
  (setv stdout (re.match r"STDOUT|-" (or options.output "STDOUT")))

  (if stdout
    (print header (.join "\n" videos))
    (do
     (-> (.open codecs options.output "w" "utf-8")
         (.write header)
         (.write (.join "\n" videos))
         (.close)))))

(defmain [&rest args]
  (argparser.add_argument "--id")
  (argparser.add_argument "--output")
  (setv args (argparser.parse_args))
  (try
   (youtube-search args)
   (except [e HttpError]
     (print "An HTTP error " e.resp.status " occured:\n" e.content))))
