#include "ConcurrentQueue.h"

namespace tns {

void ConcurrentQueue::Initialize(CFRunLoopRef runLoop, void (*performWork)(void*), void* info) {
    this->runLoop_ = runLoop;
    CFRunLoopSourceContext sourceContext = { 0, info, 0, 0, 0, 0, 0, 0, 0, performWork };
    this->runLoopTasksSource_ = CFRunLoopSourceCreate(kCFAllocatorDefault, 0, &sourceContext);
    CFRunLoopAddSource(this->runLoop_, this->runLoopTasksSource_, kCFRunLoopCommonModes);
}

void ConcurrentQueue::Push(std::string message) {
    if (this->runLoopTasksSource_ != nullptr && !CFRunLoopSourceIsValid(this->runLoopTasksSource_)) {
        return;
    }

    {
        std::unique_lock<std::mutex> mlock(this->mutex_);
        this->messagesQueue_.push(message);
    }

    this->SignalAndWakeUp();
}

std::vector<std::string> ConcurrentQueue::PopAll() {
    std::unique_lock<std::mutex> mlock(this->mutex_);
    std::vector<std::string> messages;

    while (!this->messagesQueue_.empty()) {
        std::string message = this->messagesQueue_.front();
        this->messagesQueue_.pop();
        messages.push_back(message);
    }

    return messages;
}

void ConcurrentQueue::SignalAndWakeUp() {
    if (this->runLoopTasksSource_ != nullptr) {
        assert(CFRunLoopSourceIsValid(this->runLoopTasksSource_));
        CFRunLoopSourceSignal(this->runLoopTasksSource_);
    }

    if (this->runLoop_ != nullptr) {
        CFRunLoopWakeUp(this->runLoop_);
    }
}

void ConcurrentQueue::Terminate() {
    if (this->runLoop_) {
        CFRunLoopStop(this->runLoop_);
    }

    if (this->runLoopTasksSource_) {
        CFRunLoopRemoveSource(this->runLoop_, this->runLoopTasksSource_, kCFRunLoopCommonModes);
        CFRunLoopSourceInvalidate(this->runLoopTasksSource_);
    }
}

}
