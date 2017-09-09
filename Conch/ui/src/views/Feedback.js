var m = require('mithril');
var t = require('i18n4v');

var Feedback = require('../models/Feedback');

const Icons = require('./component/Icons');


var feedbackForm = {
    view: function({attrs}) {
        return m(".feedback-form",
            m("a.feedback-form-close",
                { onclick : () => attrs.showFeedback = false },
                Icons.ui.close
            ),
            feedbackForm.submitted ?
                  m(".text-center", t("Feedback submitted"))
                : m("form.pure-form", [
                    m("legend", t("Send Feedback")),
                    m("fieldset.pure-group", [
                        m("textarea[required=true].pure-input-1", {
                            oninput: m.withAttr("value", function(v) { Feedback.text = v; }),
                            placeholder: t("Feedback placeholder"),
                            value: Feedback.text
                        }),
                        m("button[type=submit].pure-button.pure-button-primary.pure-input-1", {
                            onclick: function(e) {
                                e.preventDefault();
                                Feedback.sendUserFeedback(Feedback.text, function() {
                                    feedbackForm.submitted = true;
                                    setTimeout(function() { location.reload(); }, 1600);
                                });
                            }
                        },
                            t("Submit Feedback")
                        )
                    ])
                ])
        );
    }
};

module.exports = feedbackForm;
