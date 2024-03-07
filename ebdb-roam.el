;;; ebdb-roam.el --- Org-Roam integration for EBDB   -*- lexical-binding: t; -*-

;; Copyright (C) 2024  Free Software Foundation, Inc.

;; Authors: Samuel W. Flint <swflint@flintfam.org>, hokreb
;; Keywords:

;; This program is free software; you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation, either version 3 of the License, or
;; (at your option) any later version.

;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with this program.  If not, see <http://www.gnu.org/licenses/>.

;;; Commentary:

;;; Code:

(require 'ebdb)
(require 'ebdb-com)
(require 'ebdb-format)
(require 'org-roam-node nil t) ; It's normal if this package is missing!
(declare-function org-roam-db-query "org-roam")
(declare-function org-roam-node-id "org-node")
(declare-function org-roam-node-from-id "org-node")
(declare-function org-roam-node-p "org-node")
(declare-function magit-insert-section "magit-section")
(declare-function magit-insert-heading "magit-section")


;; org-roam-buffer Section

(defun ebdb-roam--get-links (node &optional link-type)
  "Get EBDB links of LINK-TYPE for Org Roam NODE.

NODE can be either an instance of `org-roam-node' or an Org Roam
node id (i.e., a UUID).  LINK-TYPE can be any valid EBDB link
type, if none, uuid links are searched for."
  (let* ((node (if (org-roam-node-p node)
                   node
                 (org-roam-node-from-id node)))
         (uuid (org-roam-node-id node))
         (query-result-links (org-roam-db-query [:select [dest]
                                                         :from links
                                                         :where (and (= type "ebdb")
                                                                     (= source $s1))]
                                                uuid))
         (query-result-refs (org-roam-db-query [:select [ref]
                                                        :from refs
                                                        :where (and (= type "ebdb")
                                                                    (= node_id $s1))]
                                               uuid))
         (query-results (append query-result-refs query-result-links))
         (desired-type (or link-type "uuid")))
    (cl-remove-duplicates
     (delq nil
           (mapcar (lambda (row)
                     (unless (null row)
                       (let* ((dest (car row))
                              (split-dest (split-string dest "/"))
                              (dest-type (car split-dest))
                              (dest-address (cadr split-dest)))
                         (and (string-equal dest-type desired-type) dest-address))))
                   query-results))
     :test #'string=)))

;;;###autoload
(cl-defun ebdb-roam-section (node &key (heading "Address Book Entries")
                                  (record-formatter ebdb-default-multiline-formatter))
  "Show EBDB entries for current NODE.

Appearance can be controlled with the HEADING and
RECORD-FORMATTER keyword arguments.  The former is a string to be
inserted (defaults to \"Address Book Entries\").  The latter
should be an instance of `ebdb-formatter', with a default of
`ebdb-default-multiline-formatter'."
  (when-let ((uuid-list (ebdb-roam--get-links node)))
    (with-suppressed-warnings ((free-vars org-roam-ebdb-section))
      (magit-insert-section org-roam-ebdb-section
	(magit-insert-heading heading)
	(dolist (uuid uuid-list)
          (when-let ((entry (ebdb-gethash uuid 'uuid)))
            (insert (ebdb-fmt-record record-formatter entry))))
	(insert "\n")))))

(provide 'ebdb-roam)
;;; ebdb-roam.el ends here
