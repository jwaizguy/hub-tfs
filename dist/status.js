var __extends = (this && this.__extends) || (function () {
    var extendStatics = Object.setPrototypeOf ||
        ({ __proto__: [] } instanceof Array && function (d, b) { d.__proto__ = b; }) ||
        function (d, b) { for (var p in b) if (b.hasOwnProperty(p)) d[p] = b[p]; };
    return function (d, b) {
        extendStatics(d, b);
        function __() { this.constructor = d; }
        d.prototype = b === null ? Object.create(b) : (__.prototype = b.prototype, new __());
    };
})();
define(["require", "exports", "VSS/Controls", "TFS/DistributedTask/TaskRestClient"], function (require, exports, Controls, DT_Client) {
    "use strict";
    Object.defineProperty(exports, "__esModule", { value: true });
    var StatusSection = (function (_super) {
        __extends(StatusSection, _super);
        function StatusSection() {
            return _super.call(this) || this;
        }
        StatusSection.prototype.initialize = function () {
            var _this = this;
            _super.prototype.initialize.call(this);
            // Get configuration that's shared between extension and the extension host
            var sharedConfig = VSS.getConfiguration();
            var vsoContext = VSS.getWebContext();
            if (sharedConfig) {
                // register your extension with host through callback
                sharedConfig.onBuildChanged(function (build) {
                    var taskClient = DT_Client.getClient();
                    taskClient.getPlanAttachments(vsoContext.project.id, "build", build.orchestrationPlan.planId, "blackDuckRiskReport").then(function (taskAttachments) {
                        if (taskAttachments.length === 1) {
                            var recId = taskAttachments[0].recordId;
                            var timelineId = taskAttachments[0].timelineId;
                            taskClient.getAttachmentContent(vsoContext.project.id, "build", build.orchestrationPlan.planId, timelineId, recId, "blackDuckRiskReport", "riskReport").then(function (attachementContent) {
                                function arrayBufferToString(buffer) {
                                    var bufView = new Uint16Array(buffer);
                                    var length = bufView.length;
                                    var result = '';
                                    var addition = Math.pow(2, 16) - 1;
                                    for (var i = 0; i < length; i += addition) {
                                        if (i + addition > length) {
                                            addition = length - i;
                                        }
                                        result += String.fromCharCode.apply(null, bufView.subarray(i, i + addition));
                                    }
                                    return result;
                                }
                                var summaryPageData = arrayBufferToString(attachementContent);
                                var riskObject = JSON.parse(summaryPageData.replace(/[\u200B-\u200D\uFEFF]/g, ''));
                                var container = $("<div>", { "class": "risk-report" });
                                var projectVersion = "<div class='project-version'><span>" +
                                    "<a href='" + riskObject.projectLink + "' target='_blank'>" + riskObject.projectName + "</a></span>" +
                                    "<span class='project-version-separator'><i class='fa fa-caret-right'></i></span><span>" +
                                    "<a href='" + riskObject.projectVersionLink + "' target='_blank'>" + riskObject.projectVersion + "</a></span></div>";
                                var bomCount = $("<div>", { "class": "total-count", "text": "BOM Entries: " + riskObject.totalCount });
                                var bom = $("<table>", { "class": "bom" });
                                _this._element.append(container);
                                $(".risk-report").append(projectVersion);
                                $(".risk-report").append(bomCount);
                                $(".risk-report").append(bom);
                                $(".bom").append("<tr class='bom-header-row'><th>Component</th><th>License</th><th class='security-risk-header'>Security Risk</th></tr>");
                                for (var i = 0; i < riskObject.totalCount; i++) {
                                    var highVulnClass = "";
                                    var mediumVulnClass = "";
                                    var lowVulnClass = "";
                                    if (riskObject.components[i].highVulnCount == "0") {
                                        highVulnClass = "high-vuln-count vuln-count-empty";
                                    }
                                    else {
                                        highVulnClass = "high-vuln-count";
                                    }
                                    if (riskObject.components[i].mediumVulnCount == "0") {
                                        mediumVulnClass = "medium-vuln-count vuln-count-empty";
                                    }
                                    else {
                                        mediumVulnClass = "medium-vuln-count";
                                    }
                                    if (riskObject.components[i].lowVulnCount == "0") {
                                        lowVulnClass = "low-vuln-count vuln-count-empty";
                                    }
                                    else {
                                        lowVulnClass = "low-vuln-count";
                                    }
                                    $(".bom-header-row").after("<tr><td>" +
                                        "<a href='" + riskObject.components[i].componentLink + "' target='_blank'>" +
                                        riskObject.components[i].component + " " + riskObject.components[i].version + "</a>" +
                                        "</td><td>" + riskObject.components[i].license +
                                        "</td><td>" +
                                        "<div class='risk-panel'>" +
                                        "<span class='" + highVulnClass + "'>" +
                                        riskObject.components[i].highVulnCount +
                                        "</span>" +
                                        "<span class='" + mediumVulnClass + "'>" +
                                        riskObject.components[i].mediumVulnCount +
                                        "</span>" +
                                        "<span class='" + lowVulnClass + "'>" +
                                        riskObject.components[i].lowVulnCount +
                                        "</span>" +
                                        "</div></td></tr>");
                                }
                            });
                        }
                    });
                });
            }
        };
        return StatusSection;
    }(Controls.BaseControl));
    exports.StatusSection = StatusSection;
    StatusSection.enhance(StatusSection, $(".black-duck-risk-report"), {});
    VSS.notifyLoadSucceeded();
});