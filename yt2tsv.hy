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
  (let [s (.split value ":")]
    (-> (if (= (len s) 1)
          (-> item (get (car s)))
          (-> item
              (get (car s))
              (get (last s))))
        (.encode "utf8"))))
(defreader ^ [expr] `(youtube-api-get item ~@expr))

(defn youtube-extract [item]
  {"Video URL" (+ "https://youtu.be/" #^("id"))
   "Title" #^("snippet:title")
   "Channel URL" (+ "https://youtube.com/channel/" #^("snippet:channelId"))
   "Channel" #^("snippet:channelTitle")
   "Views" #^("statistics:viewCount")
   "Likes" #^("statistics:likeCount")
   "Dislikes" #^("statistics:dislikeCount")})

(defn youtube-get [ids]
  (let [youtube (build SERVICE-NAME API-VERSION
                       :developerKey DEVELOPER-KEY)
        items []
        chunked (list (partition ids 30 :fillvalue None))]
    (for [chunk chunked]
      (do
       (setv chunk-ids (.join "," (list (take-while string? chunk))))
       (setv response (-> (.videos youtube)
                          (.list :id chunk-ids :part "snippet,statistics")
                          (.execute)))
       (for [result (.get response "items")]
         (.append items (youtube-extract result)))))
    items))

(defn get-and-convert-to-csv [options]
  (unless (or options.id
              (and options.input (os.path.isfile options.input)))
    (sys.exit "No valid input"))

  (setv videos (youtube-get
                (if (os.path.isfile options.input)
                  (file-to-ids options.input)
                  (or (.split options.id ",") None))))

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
   (-> (re.search pattern line) .groups car)
   (except [e AttributeError] "")))

(defn file-to-ids [input-file]
  (setv ids [])
  (with [f (open input-file)]
        (for [line (.readlines f)]
          (setv id (url-to-video-id line))
          (when id (.append ids id))))
  ids)

(defmain [&rest args]
  (argparser.add-argument "--id")
  (argparser.add-argument "--input")
  (argparser.add-argument "--output" :default "output.tsv")
  (setv args (argparser.parse-args))
  (unless (or args.input args.id)
    (argparser.error "either --id or --input required"))
  (try
   (get-and-convert-to-csv args)
   (except [e HttpError]
     (print "An HTTP error " e.resp.status " occured:\n" e.content))))
