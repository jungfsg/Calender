from typing import List, Dict, Any, Optional
from datetime import datetime
import json
import os
from pathlib import Path

class EventStorageService:
    def __init__(self):
        self.storage_dir = Path("data/events")
        self.storage_dir.mkdir(parents=True, exist_ok=True)
        self.events_file = self.storage_dir / "events.json"
        self._load_events()

    def _load_events(self):
        """저장된 일정을 로드합니다."""
        if self.events_file.exists():
            with open(self.events_file, 'r', encoding='utf-8') as f:
                self.events = json.load(f)
        else:
            self.events = []
            self._save_events()

    def _save_events(self):
        """일정을 파일에 저장합니다."""
        with open(self.events_file, 'w', encoding='utf-8') as f:
            json.dump(self.events, f, ensure_ascii=False, indent=2)

    def create_event(self, event_data: Dict[str, Any]) -> Dict[str, Any]:
        """새로운 일정을 생성합니다."""
        event_id = str(len(self.events) + 1)
        event = {
            "id": event_id,
            **event_data,
            "created_at": datetime.now().isoformat(),
            "updated_at": datetime.now().isoformat()
        }
        self.events.append(event)
        self._save_events()
        return event

    def update_event(self, event_id: str, event_data: Dict[str, Any]) -> Optional[Dict[str, Any]]:
        """기존 일정을 수정합니다."""
        for event in self.events:
            if event["id"] == event_id:
                event.update(event_data)
                event["updated_at"] = datetime.now().isoformat()
                self._save_events()
                return event
        return None

    def delete_event(self, event_id: str) -> bool:
        """일정을 삭제합니다."""
        for i, event in enumerate(self.events):
            if event["id"] == event_id:
                del self.events[i]
                self._save_events()
                return True
        return False

    def get_events(self, start_date: Optional[str] = None, end_date: Optional[str] = None) -> List[Dict[str, Any]]:
        """일정을 조회합니다."""
        if not start_date and not end_date:
            return self.events

        filtered_events = []
        for event in self.events:
            event_start = event.get("start_date")
            event_end = event.get("end_date")

            if start_date and event_start < start_date:
                continue
            if end_date and event_end > end_date:
                continue

            filtered_events.append(event)

        return filtered_events

    def search_events(self, query: str) -> List[Dict[str, Any]]:
        """일정을 검색합니다."""
        query = query.lower()
        results = []
        for event in self.events:
            if (query in event.get("title", "").lower() or
                query in event.get("description", "").lower() or
                query in event.get("location", "").lower()):
                results.append(event)
        return results 