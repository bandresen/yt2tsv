#!/usr/bin/env hy

(import re codecs csv sys os
        [apiclient.discovery [build]]
        [apiclient.errors [HttpError]]
        [oauth2client.tools [argparser]])

(setv DEVELOPER-KEY (-> (open "key") .read .strip))
(setv SERVICE-NAME "youtube")
(setv API-VERSION "v3")

(setv HEADERS ["Video URL" "Title" "Channel URL" "Channel" "Views" "Likes" "Dislikes"])

(defn youtube-api-get [item value]
  (setv s (.split value ":"))
  (-> (if (= (len s) 1)
        (-> item (get (first s)))
        (-> item
            (get (first s))
            (get (last s))))))

(defsharp ^ [expr] `(youtube-api-get item ~@expr))

(defn youtube-extract [item]
  {"Video URL" (+ "https://youtu.be/" #^("id"))
   "Title" #^("snippet:title")
   "Channel URL" (+ "https://youtube.com/channel/" #^("snippet:channelId"))
   "Channel" #^("snippet:channelTitle")
   "Views" #^("statistics:viewCount")
   "Likes" #^("statistics:likeCount")
   "Dislikes" #^("statistics:dislikeCount")})

(defn youtube-get [ids]
  (setv youtube (build SERVICE-NAME API-VERSION
                       :developerKey DEVELOPER-KEY))
  (setv items [])
  (setv chunked (list (partition ids 30 :fillvalue None)))
  (for [chunk chunked]
    (do
     (setv chunk-ids (.join "," (list (take-while string? chunk))))
     (setv response (-> (.videos youtube)
                        (.list :id chunk-ids :part "snippet,statistics")
                        (.execute)))
     (for [result (.get response "items")]
       (.append items (youtube-extract result)))))
  items)

(defn get-and-convert-to-csv [options]
  (unless (or options.ids options.input)
    (sys.exit "No valid input"))
  (if options.input (unless (os.path.isfile options.input)
                      (sys.exit (+ "Not a file: " options.input))))

  (setv videos (youtube-get
                (if options.ids
                  (.split options.ids ",")
                  (file-to-ids options.input))))

  (with [csv-file (open options.output "w")]
        (setv writer (csv.DictWriter csv-file
                                     :delimiter (str "\t")
                                     :fieldnames HEADERS))
        (.writeheader writer)
        (for [entry videos]
          (.writerow writer entry))))

(defn url-to-video-id [line]
  (setv pattern (re.compile r"(?:https?:\/\/)?(?:[0-9A-Z-]+\.)?(?:youtube|youtu|youtube-nocookie)\.(?:com|be)\/(?:watch\?v=|watch\?.+&v=|embed\/|v\/|.+\?v=)?([^&=\n%\?]{11})" re.IGNORECASE))
  (try
   (-> (re.search pattern line) .groups first)
   (except [e AttributeError] "")))

(defn file-to-ids [input-file]
  (setv ids [])
  (with [f (open input-file)]
        (for [line (.readlines f)]
          (setv id (url-to-video-id line))
          (when id (.append ids id))))
  ids)

(defmain [&rest args]
  (argparser.add-argument "--ids")
  (argparser.add-argument "--input")
  (argparser.add-argument "--output" :default "output.tsv")
  (setv args (argparser.parse-args))
  (unless (or args.input args.ids)
    (argparser.error "either --ids or --input required"))
  (try
   (get-and-convert-to-csv args)
   (except [e HttpError]
     (print "An HTTP error " e.resp.status " occured:\n" e.content))))
