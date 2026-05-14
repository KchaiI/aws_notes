import json
import os
import urllib.request
import urllib.error


def lambda_handler(event, context):
    """
    Step Functionsから渡されたイベントをSlackに通知する
    """
    webhook_url = os.environ["SLACK_WEBHOOK_URL"]

    # Step Functionsからの入力を取得
    message = event.get("message", "通知が届きました")
    source = event.get("source", "unknown")

    payload = {
        "text": message
    }

    req = urllib.request.Request(
        webhook_url,
        data=json.dumps(payload).encode("utf-8"),
        headers={"Content-Type": "application/json"},
        method="POST",
    )

    try:
        with urllib.request.urlopen(req, timeout=5) as resp:
            body = resp.read().decode("utf-8")
            print(f"Slack response: status={resp.status} body={body}")
            return {
                "statusCode": resp.status,
                "body": body,
            }
    except urllib.error.HTTPError as e:
        err_body = e.read().decode("utf-8")
        print(f"Slack HTTPError: status={e.code} body={err_body}")
        raise
    except urllib.error.URLError as e:
        print(f"Slack URLError: {e.reason}")
        raise
